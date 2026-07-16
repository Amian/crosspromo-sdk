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

  final CrossPromoConfiguration configuration;
  final CrossPromoTransport _transport;
  final CrossPromoPlatform _platform;
  _Session? _session;
  Future<_Session>? _sessionRequest;

  Future<CrossPromoSessionStatus> sessionStatus() async =>
      (await _validSession()).status;

  Future<PromoCardData?> fetchCard({
    required CrossPromoPlacement placement,
  }) async {
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
    if (existing != null &&
        existing.status.expiresAt.difference(DateTime.now()) >
            const Duration(seconds: 30)) {
      return existing;
    }
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

  Future<_Session> _createSession() async {
    final app = await _platform.getAppContext();
    final challenge = await _post('/v1/sdk/sessions/challenge', {
      'app_key': configuration.appKey,
      'environment': configuration.environment.name,
      'app': app.toJson(),
      'sdk': {'name': 'crosspromo-flutter', 'version': '0.3.0'},
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

  static void configure({
    required String appKey,
    CrossPromoEnvironment environment = CrossPromoEnvironment.production,
    Uri? baseUri,
  }) {
    _client = CrossPromoClient(
      CrossPromoConfiguration(
        appKey: appKey,
        environment: environment,
        baseUri: baseUri,
      ),
    );
  }

  static CrossPromoClient get client {
    final value = _client;
    if (value == null) {
      throw StateError('Call CrossPromo.configure before using the SDK.');
    }
    return value;
  }
}
