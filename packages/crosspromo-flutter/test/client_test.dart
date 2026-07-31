import 'dart:async';
import 'dart:convert';

import 'package:crosspromo_sdk/src/client.dart';
import 'package:crosspromo_sdk/src/configuration.dart';
import 'package:crosspromo_sdk/src/icon_warmer.dart';
import 'package:crosspromo_sdk/src/models.dart';
import 'package:crosspromo_sdk/src/platform_bridge.dart';
import 'package:crosspromo_sdk/src/transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatically selects the build environment', () {
    final configuration = CrossPromoConfiguration(appKey: 'cp_live_example');
    expect(
      configuration.environment,
      kDebugMode
          ? CrossPromoEnvironment.sandbox
          : CrossPromoEnvironment.production,
    );
  });

  test('allows an explicit production override', () {
    final configuration = CrossPromoConfiguration(
      appKey: 'cp_live_example',
      environment: CrossPromoEnvironment.production,
    );
    expect(configuration.environment, CrossPromoEnvironment.production);
  });

  test('sends app identity and only reports qualified impressions', () async {
    final transport = FakeTransport();
    final client = CrossPromoClient(
      CrossPromoConfiguration(
        appKey: 'cp_live_example',
        baseUri: Uri.parse('https://example.test'),
      ),
      transport: transport,
      platform: FakePlatform(),
    );

    final card = await client.fetchCard(
      placement: CrossPromoPlacement.postScan,
    );
    expect(card?.cardId, 'c_1');
    await client.recordImpression(
      card!,
      visibleFraction: 0.49,
      duration: const Duration(seconds: 2),
    );
    expect(transport.requests, hasLength(3));
    await client.recordImpression(
      card,
      visibleFraction: 0.75,
      duration: const Duration(milliseconds: 1100),
    );

    expect(transport.requests.map((r) => r.path), [
      '/v1/sdk/sessions/challenge',
      '/v1/sdk/sessions/verify',
      '/v1/cards',
      '/v1/events/impressions',
    ]);
    final app = transport.requests.first.body['app']! as Map<String, Object?>;
    final sdk = transport.requests.first.body['sdk']! as Map<String, Object?>;
    expect(
      transport.requests.first.body['environment'],
      kDebugMode ? 'sandbox' : 'production',
    );
    expect(app['bundle_id'], 'app.example.publisher');
    expect(app['version'], '3.2.1');
    expect(sdk['version'], '0.3.6');
    expect(
        transport.requests.first.body.containsKey('installation_id'), isFalse);
    expect(transport.requests.first.body.containsKey('locale'), isFalse);
    expect(transport.requests.first.body.containsKey('integrity'), isFalse);
    final evidence =
        transport.requests[1].body['evidence']! as Map<String, Object?>;
    expect(evidence['provider'], 'app_transaction');
    expect(evidence['app_transaction_jws'], 'apple.signed.jws');
    // The card request no longer names a slot; the impression does, because that
    // is where the ad was actually seen.
    expect(transport.requests[2].body.containsKey('placement'), isFalse);
    expect(transport.requests[3].body['placement'], 'post_scan');
    expect(transport.requests.last.idempotencyKey, isNotNull);
  });

  test('a prefetched card is served without any further network call', () async {
    final transport = FakeTransport();
    final client = newClient(transport);

    await client.prefetch();
    expect(transport.requests.map((r) => r.path), [
      '/v1/sdk/sessions/challenge',
      '/v1/sdk/sessions/verify',
      '/v1/cards',
    ]);

    final card = await client.fetchCard(
      placement: CrossPromoPlacement.postScan,
    );
    expect(card?.cardId, 'c_1');
    expect(
      transport.requests,
      hasLength(3),
      reason: 'showing a prefetched card must not touch the network',
    );
  });

  test('a prefetched card is single use, because its impression token is',
      () async {
    final transport = FakeTransport();
    final client = newClient(transport);

    await client.prefetch();
    final first =
        await client.fetchCard(placement: CrossPromoPlacement.postScan);
    final second =
        await client.fetchCard(placement: CrossPromoPlacement.postScan);

    expect(first?.cardId, 'c_1');
    expect(second?.cardId, 'c_2', reason: 'the second card must be a fresh one');
    expect(first?.impressionToken, isNot(second?.impressionToken));
    expect(transport.cardRequestCount, 2);
  });

  test('one prefetched card fills whichever placement asks for it first',
      () async {
    // Placement never changes which ad the backend picks, so a card held from
    // before we knew the slot is perfectly good for any of them.
    final transport = FakeTransport();
    final client = newClient(transport);

    await client.prefetch();
    final card = await client.fetchCard(placement: CrossPromoPlacement.settings);

    expect(card?.cardId, 'c_1', reason: 'the held card is used, not a new one');
    expect(transport.cardRequestCount, 1);
  });

  test('the card request no longer pins the card to a slot', () async {
    final transport = FakeTransport();
    final client = newClient(transport);

    await client.fetchCard(placement: CrossPromoPlacement.postScan);

    final cardRequest =
        transport.requests.firstWhere((r) => r.path == '/v1/cards');
    expect(
      cardRequest.body.containsKey('placement'),
      isFalse,
      reason: 'the slot is reported when the ad is seen, not when it is fetched',
    );
  });

  test('the impression reports the slot the card was actually shown in',
      () async {
    final transport = FakeTransport();
    final client = newClient(transport);

    final card =
        await client.fetchCard(placement: CrossPromoPlacement.emptyState);
    await client.recordImpression(
      card!,
      visibleFraction: 0.9,
      duration: const Duration(seconds: 2),
    );

    final impression =
        transport.requests.firstWhere((r) => r.path == '/v1/events/impressions');
    expect(impression.body['placement'], 'empty_state');
  });

  test('the click link carries the slot too', () async {
    final transport = FakeTransport();
    final platform = FakePlatform();
    final client = CrossPromoClient(
      CrossPromoConfiguration(
        appKey: 'cp_live_example',
        baseUri: Uri.parse('https://example.test'),
      ),
      transport: transport,
      platform: platform,
      iconWarmer: (_) {},
    );

    final card = await client.fetchCard(placement: CrossPromoPlacement.result);
    await client.open(card!);

    expect(platform.openedUrls.single.queryParameters['placement'], 'result');
  });

  test('a prefetched card too close to expiry is discarded, not shown',
      () async {
    // Below the client's freshness margin: it could expire before the viewability
    // window it is about to be measured against completes.
    final transport = FakeTransport(cardLifetime: const Duration(seconds: 5));
    final client = newClient(transport);

    await client.prefetch();
    expect(transport.cardRequestCount, 1);

    final card = await client.fetchCard(
      placement: CrossPromoPlacement.postScan,
    );
    expect(transport.cardRequestCount, 2, reason: 'the stale card is refetched');
    expect(card?.cardId, 'c_2');
  });

  test('a card requested while a prefetch is in flight reuses that request',
      () async {
    final gate = Completer<void>();
    final transport = FakeTransport(cardGate: gate.future);
    final client = newClient(transport);

    final warming = client.prefetch();
    final pending = client.fetchCard(placement: CrossPromoPlacement.postScan);
    gate.complete();
    final card = await pending;
    await warming;

    expect(card?.cardId, 'c_1');
    expect(
      transport.cardRequestCount,
      1,
      reason: 'a mount during prefetch must not start a second card request',
    );
  });

  test('a failed prefetch stays silent and the card is fetched on demand',
      () async {
    final transport = FakeTransport(failCards: true);
    final client = newClient(transport);

    // Must not throw: nothing was on screen when this ran.
    await client.prefetch();

    await expectLater(
      client.fetchCard(placement: CrossPromoPlacement.postScan),
      throwsA(isA<CrossPromoException>()),
    );
    expect(transport.cardRequestCount, 2);
  });

  test('prefetching also warms the card icon', () async {
    final transport = FakeTransport();
    final warmed = <Uri>[];
    final client = newClient(transport, iconWarmer: warmed.add);

    await client.prefetch();

    expect(warmed, [Uri.parse('https://cdn.example/icon.png')]);
  });

  test('a prefetch that returns no card warms nothing', () async {
    final transport = FakeTransport(failCards: true);
    final warmed = <Uri>[];
    final client = newClient(transport, iconWarmer: warmed.add);

    await client.prefetch();

    expect(warmed, isEmpty);
  });

  test('an icon warmer that throws cannot break the prefetch', () async {
    // The warmer touches the image cache, which needs a binding that may not exist
    // wherever configure() was called. A failure there must not lose the card.
    final transport = FakeTransport();
    final client = newClient(
      transport,
      iconWarmer: (_) => throw StateError('no binding'),
    );

    await client.prefetch();
    final card = await client.fetchCard(
      placement: CrossPromoPlacement.postScan,
    );

    expect(
      card?.cardId,
      'c_1',
      reason: 'the prefetched card survives a warmer failure',
    );
    expect(transport.cardRequestCount, 1);
  });

  test('concurrent prefetches for one placement share a single fetch', () async {
    final transport = FakeTransport();
    final client = newClient(transport);

    await Future.wait([
      client.prefetch(),
      client.prefetch(),
      client.prefetch(),
    ]);

    expect(transport.cardRequestCount, 1);
    expect(
      transport.requests.where((r) => r.path == '/v1/sdk/sessions/challenge'),
      hasLength(1),
      reason: 'the handshake must not be repeated either',
    );
  });
}

CrossPromoClient newClient(
  FakeTransport transport, {
  CrossPromoIconWarmer? iconWarmer,
}) =>
    CrossPromoClient(
      CrossPromoConfiguration(
        appKey: 'cp_live_example',
        baseUri: Uri.parse('https://example.test'),
      ),
      transport: transport,
      platform: FakePlatform(),
      // Default to a no-op: the real warmer touches the image cache, which needs a
      // binding these plain unit tests do not set up.
      iconWarmer: iconWarmer ?? (_) {},
    );

class RequestRecord {
  RequestRecord(this.path, this.body, this.idempotencyKey);

  final String path;
  final Map<String, Object?> body;
  final String? idempotencyKey;
}

class FakeTransport implements CrossPromoTransport {
  FakeTransport({this.cardLifetime, this.cardGate, this.failCards = false});

  /// How long each served card stays valid. Defaults to the far future.
  final Duration? cardLifetime;

  /// When set, every `/v1/cards` response waits on this before completing, so a
  /// test can observe behaviour while a card request is still in flight.
  final Future<void>? cardGate;

  /// Makes `/v1/cards` fail, to prove a failed prefetch stays invisible.
  final bool failCards;

  final requests = <RequestRecord>[];
  int _cardsServed = 0;

  int get cardRequestCount =>
      requests.where((r) => r.path == '/v1/cards').length;

  @override
  Future<CrossPromoHttpResponse> post(
    Uri uri,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
  }) async {
    requests.add(RequestRecord(uri.path, body, idempotencyKey));
    if (uri.path == '/v1/cards') {
      if (cardGate != null) await cardGate;
      if (failCards) {
        return const CrossPromoHttpResponse(statusCode: 500, body: '{}');
      }
    }
    final cardExpiresAt = cardLifetime == null
        ? '2099-01-01T00:00:00Z'
        : DateTime.now().toUtc().add(cardLifetime!).toIso8601String();
    final response = switch (uri.path) {
      '/v1/sdk/sessions/challenge' => {
          'session_id': 's_1',
          'challenge_base64': 'aGVsbG8=',
          'integrity_mode': 'app_transaction',
        },
      '/v1/sdk/sessions/verify' => {
          'access_token': 'token',
          'publisher_app_id': 'app_1',
          'counts_enabled': true,
          'reason': null,
          'expires_at': '2099-01-01T00:00:00Z',
        },
      '/v1/cards' => {
          'card': {
            'card_id': 'c_${++_cardsServed}',
            'app_name': 'Rock Finder',
            'icon_url': 'https://cdn.example/icon.png',
            'tagline': 'Find every rock',
            'cta': 'Get',
            'click_url': 'https://go.example/c/1',
            'impression_token': 'imp_$_cardsServed',
            'expires_at': cardExpiresAt,
          },
        },
      '/v1/events/impressions' => null,
      _ => throw StateError('Unexpected path ${uri.path}'),
    };
    return CrossPromoHttpResponse(
      statusCode: 200,
      body: response == null ? '' : jsonEncode(response),
    );
  }
}

class FakePlatform implements CrossPromoPlatform {
  @override
  Future<AppContext> getAppContext() async => const AppContext(
        platform: 'ios',
        bundleId: 'app.example.publisher',
        version: '3.2.1',
        buildNumber: '42',
      );

  @override
  Future<IntegrityEvidence> generateEvidence({
    required String challengeBase64,
    required String mode,
    int? cloudProjectNumber,
  }) async =>
      const IntegrityEvidence(
        provider: 'app_transaction',
        appTransactionJws: 'apple.signed.jws',
      );

  final openedUrls = <Uri>[];

  @override
  Future<void> openUrl(Uri url) async => openedUrls.add(url);
}
