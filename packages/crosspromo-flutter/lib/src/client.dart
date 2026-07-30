import 'dart:async';
import 'dart:convert';

import 'configuration.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'transport.dart';

class CrossPromoException implements Exception {
  const CrossPromoException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'CrossPromoException: $message'
      : 'CrossPromoException ($statusCode): $message';
}

class CrossPromoClient {
  CrossPromoClient(
    this.configuration, {
    CrossPromoTransport? transport,
    CrossPromoPlatform? platform,
  })  : _transport =
            transport ?? IoCrossPromoTransport(configuration.requestTimeout),
        _platform = platform ?? MethodChannelCrossPromoPlatform();

  /// A session this close to expiring is renewed before it is handed out, so a
  /// request can never be signed with a token that dies mid-flight.
  static const _sessionMinimumRemaining = Duration(seconds: 30);

  /// A still-valid session with less than this left is renewed in the background,
  /// so an ad request practically never waits for the three-call handshake.
  static const _sessionRefreshMargin = Duration(minutes: 2);

  /// A prefetched card has to outlive the viewability window it is about to be
  /// measured against, so one that is nearly expired is discarded rather than
  /// shown and then failing to record.
  static const _cardMinimumRemaining = Duration(seconds: 30);

  final CrossPromoConfiguration configuration;
  final CrossPromoTransport _transport;
  final CrossPromoPlatform _platform;
  _Session? _session;
  Future<_Session>? _sessionRequest;

  /// Cards fetched ahead of being needed, keyed by placement.
  ///
  /// Cards are single use: each carries its own impression token, and the backend
  /// treats a repeated token as a replay. Handing one card to two placements would
  /// therefore silently drop the second impression, so taking a prefetched card
  /// removes it from here.
  final Map<String, PromoCardData> _prefetched = {};
  final Map<String, Future<void>> _prefetchRequests = {};

  Future<CrossPromoSessionStatus> sessionStatus() async =>
      (await _validSession()).status;

  /// Does the slow part of showing an ad before there is anywhere to show it: the
  /// session handshake and one card fetch. Call it at app start, or as soon as you
  /// know a placement is coming, and the matching [fetchCard] returns immediately.
  ///
  /// Best effort by design — failures are swallowed, because a prefetch that did
  /// not work must not surface as an error at a point where the app was not even
  /// showing an ad. The card is simply fetched on demand instead.
  ///
  /// Safe to call repeatedly: concurrent calls for one placement share a single
  /// fetch, and a placement that already holds a fresh card does nothing.
  Future<void> prefetch({
    required CrossPromoPlacement placement,
  }) {
    final key = placement.value;
    final inflight = _prefetchRequests[key];
    if (inflight != null) return inflight;
    if (_prefetched[key] != null) return Future<void>.value();
    final request = _runPrefetch(key, placement);
    _prefetchRequests[key] = request;
    return request;
  }

  /// Warms only the session handshake, for apps that want the credential ready
  /// without holding a card that could go stale.
  Future<void> warmUp() async {
    try {
      await _validSession();
    } on Object {
      // Best effort, exactly like prefetch.
    }
  }

  Future<void> _runPrefetch(String key, CrossPromoPlacement placement) async {
    try {
      final card = await _requestCard(placement);
      if (card != null) _prefetched[key] = card;
    } on Object {
      // Swallowed: see prefetch's contract.
    } finally {
      _prefetchRequests.remove(key);
    }
  }

  Future<PromoCardData?> fetchCard({
    required CrossPromoPlacement placement,
  }) async {
    final key = placement.value;
    final ready = _takePrefetched(key);
    if (ready != null) return ready;

    // A prefetch already on the wire: wait for it rather than starting a second
    // identical request and wasting the impression the first one is holding.
    final inflight = _prefetchRequests[key];
    if (inflight != null) {
      await inflight;
      final arrived = _takePrefetched(key);
      if (arrived != null) return arrived;
    }
    return _requestCard(placement);
  }

  PromoCardData? _takePrefetched(String key) {
    final held = _prefetched.remove(key);
    if (held == null) return null;
    final remaining = held.expiresAt.difference(DateTime.now());
    return remaining > _cardMinimumRemaining ? held : null;
  }

  Future<PromoCardData?> _requestCard(CrossPromoPlacement placement) async {
    final session = await _validSession();
    final json = await _post(
        '/v1/cards',
        {
          'placement': placement.value,
        },
        bearerToken: session.accessToken);
    final card = json['card'];
    return card == null
        ? null
        : PromoCardData.fromJson((card as Map).cast<String, Object?>());
  }

  Future<void> recordImpression(
    PromoCardData card, {
    required double visibleFraction,
    required Duration duration,
  }) async {
    if (visibleFraction < 0.5 || duration < const Duration(seconds: 1)) return;
    final session = await _validSession();
    await _post(
      '/v1/events/impressions',
      {
        'impression_token': card.impressionToken,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'viewability': {
          'visible_fraction': visibleFraction.clamp(0, 1),
          'duration_ms': duration.inMilliseconds,
        },
      },
      bearerToken: session.accessToken,
      idempotencyKey: _randomId(),
      allowEmpty: true,
    );
  }

  Future<void> open(PromoCardData card) => _platform.openUrl(card.clickUrl);

  Future<_Session> _validSession() async {
    final existing = _session;
    if (existing != null) {
      final remaining = existing.status.expiresAt.difference(DateTime.now());
      if (remaining > _sessionMinimumRemaining) {
        if (remaining < _sessionRefreshMargin) {
          // Still usable, but close enough to expiry that the next ad would have
          // paid for a fresh handshake. Renew behind this request and answer it
          // with the token we already hold.
          _renewSessionInBackground();
        }
        return existing;
      }
    }
    return _startSession();
  }

  Future<_Session> _startSession() async {
    final inflight = _sessionRequest;
    if (inflight != null) return inflight;
    final request = _createSession();
    _sessionRequest = request;
    try {
      final session = await request;
      _session = session;
      return session;
    } finally {
      _sessionRequest = null;
    }
  }

  void _renewSessionInBackground() {
    if (_sessionRequest != null) return;
    unawaited(_startSession().then((_) {}, onError: (Object _) {}));
  }

  Future<_Session> _createSession() async {
    final app = await _platform.getAppContext();
    final challenge = await _post('/v1/sdk/sessions/challenge', {
      'app_key': configuration.appKey,
      'environment': configuration.environment.name,
      'app': app.toJson(),
      'sdk': {'name': 'crosspromo-flutter', 'version': '0.3.4'},
    });
    final evidence = await _platform.generateEvidence(
      challengeBase64: challenge['challenge_base64']! as String,
      mode: challenge['integrity_mode']! as String,
      cloudProjectNumber: (challenge['cloud_project_number'] as num?)?.toInt(),
    );
    final verified = await _post('/v1/sdk/sessions/verify', {
      'session_id': challenge['session_id']! as String,
      'evidence': evidence.toJson(),
    });
    final status = CrossPromoSessionStatus(
      publisherAppId: verified['publisher_app_id']! as String,
      countsEnabled: verified['counts_enabled']! as bool,
      reason: verified['reason'] as String?,
      expiresAt: DateTime.parse(verified['expires_at']! as String),
    );
    return _Session(verified['access_token']! as String, status);
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
    bool allowEmpty = false,
  }) async {
    final response = await _transport.post(
      configuration.baseUri.resolve(path),
      body,
      bearerToken: bearerToken,
      idempotencyKey: idempotencyKey,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed';
      try {
        final error = jsonDecode(response.body) as Map<String, Object?>;
        final details = error['error'] as Map<String, Object?>?;
        message = details?['message'] as String? ?? message;
      } on FormatException {
        // Keep the generic message for a non-JSON error page.
      }
      throw CrossPromoException(message, statusCode: response.statusCode);
    }
    if (response.body.isEmpty && allowEmpty) return const {};
    try {
      return (jsonDecode(response.body) as Map).cast<String, Object?>();
    } on FormatException {
      throw const CrossPromoException('The API returned invalid JSON');
    }
  }

  String _randomId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = identityHashCode(Object()).toRadixString(16);
    return '$now-$salt';
  }
}

class _Session {
  const _Session(this.accessToken, this.status);

  final String accessToken;
  final CrossPromoSessionStatus status;
}

abstract final class CrossPromo {
  static CrossPromoClient? _client;

  /// [prefetchPlacements] warms the session and one card for each placement given,
  /// in the background, so the first card the app shows appears without a network
  /// wait. Pass the placements the app actually uses — a prefetched card is held
  /// until something asks for it, and anything that fails is fetched on demand.
  static void configure({
    required String appKey,
    CrossPromoEnvironment? environment,
    Uri? baseUri,
    Iterable<CrossPromoPlacement> prefetchPlacements = const [],
  }) {
    final client = CrossPromoClient(
      CrossPromoConfiguration(
        appKey: appKey,
        environment: environment,
        baseUri: baseUri,
      ),
    );
    _client = client;
    for (final placement in prefetchPlacements) {
      unawaited(client.prefetch(placement: placement));
    }
  }

  static CrossPromoClient get client {
    final value = _client;
    if (value == null) {
      throw StateError('Call CrossPromo.configure before using the SDK.');
    }
    return value;
  }
}
