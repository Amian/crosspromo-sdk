import 'dart:convert';

import 'package:crosspromo_sdk/src/client.dart';
import 'package:crosspromo_sdk/src/configuration.dart';
import 'package:crosspromo_sdk/src/models.dart';
import 'package:crosspromo_sdk/src/platform_bridge.dart';
import 'package:crosspromo_sdk/src/transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(transport.requests.first.body['environment'], 'production');
    expect(app['bundle_id'], 'app.example.publisher');
    expect(app['version'], '3.2.1');
    final integrity =
        transport.requests.first.body['integrity']! as Map<String, Object?>;
    expect(integrity['provider'], 'app_transaction');
    expect(integrity['app_transaction_jws'], 'apple.signed.jws');
    final evidence =
        transport.requests[1].body['evidence']! as Map<String, Object?>;
    expect(evidence['provider'], 'app_transaction');
    expect(evidence['app_transaction_jws'], 'apple.signed.jws');
    expect(transport.requests[2].body['placement'], 'post_scan');
    expect(transport.requests.last.idempotencyKey, isNotNull);
  });
}

class RequestRecord {
  RequestRecord(this.path, this.body, this.idempotencyKey);

  final String path;
  final Map<String, Object?> body;
  final String? idempotencyKey;
}

class FakeTransport implements CrossPromoTransport {
  final requests = <RequestRecord>[];

  @override
  Future<CrossPromoHttpResponse> post(
    Uri uri,
    Map<String, Object?> body, {
    String? bearerToken,
    String? idempotencyKey,
  }) async {
    requests.add(RequestRecord(uri.path, body, idempotencyKey));
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
            'card_id': 'c_1',
            'app_name': 'Rock Finder',
            'icon_url': 'https://cdn.example/icon.png',
            'tagline': 'Find every rock',
            'cta': 'Get',
            'click_url': 'https://go.example/c/1',
            'impression_token': 'imp_1',
            'expires_at': '2099-01-01T00:00:00Z',
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
        installationId: 'install_1',
        platform: 'ios',
        bundleId: 'app.example.publisher',
        version: '3.2.1',
        buildNumber: '42',
      );

  @override
  Future<IntegrityPreparation> prepareIntegrity() async =>
      const IntegrityPreparation(
        provider: 'app_transaction',
        appTransactionJws: 'apple.signed.jws',
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

  @override
  Future<void> openUrl(Uri url) async {}

  @override
  Future<void> resetInstallationId() async {}
}
