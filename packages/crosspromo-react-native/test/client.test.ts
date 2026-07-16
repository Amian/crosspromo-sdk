import assert from 'node:assert/strict';
import test from 'node:test';

import { CrossPromoClient } from '../src/client';
import type {
  CrossPromoPlatform,
  Fetch,
  IntegrityEvidence,
  IntegrityPreparation,
} from '../src/types';

test('sends app identity and only reports qualified impressions', async () => {
  const requests: Array<{ path: string; body: Record<string, unknown>; headers: HeadersInit }> = [];
  const responses: Record<string, unknown> = {
    '/v1/sdk/sessions/challenge': {
      session_id: 's_1',
      challenge_base64: 'aGVsbG8=',
      integrity_mode: 'attestation',
    },
    '/v1/sdk/sessions/verify': {
      access_token: 'token',
      publisher_app_id: 'app_1',
      counts_enabled: true,
      reason: null,
      expires_at: '2099-01-01T00:00:00Z',
    },
    '/v1/cards': {
      card: {
        card_id: 'c_1',
        app_name: 'Rock Finder',
        icon_url: 'https://cdn.example/icon.png',
        tagline: 'Find every rock',
        cta: 'Get',
        click_url: 'https://go.example/c/1',
        impression_token: 'imp_1',
        expires_at: '2099-01-01T00:00:00Z',
      },
    },
    '/v1/events/impressions': undefined,
  };
  const fetcher: Fetch = async (url, init) => {
    const path = new URL(url).pathname;
    requests.push({
      path,
      body: JSON.parse(String(init?.body)) as Record<string, unknown>,
      headers: init?.headers ?? {},
    });
    const response = responses[path];
    return {
      ok: true,
      status: 200,
      text: async () => (response === undefined ? '' : JSON.stringify(response)),
    };
  };
  const client = new CrossPromoClient(
    { appKey: 'cp_test_example', baseUrl: 'https://example.test' },
    new FakePlatform(),
    fetcher,
  );

  const card = await client.fetchCard('post_scan');
  assert.equal(card?.cardId, 'c_1');
  await client.recordImpression(card!, 0.49, 2_000);
  assert.equal(requests.length, 3);
  await client.recordImpression(card!, 0.75, 1_100);

  assert.deepEqual(
    requests.map(({ path }) => path),
    [
      '/v1/sdk/sessions/challenge',
      '/v1/sdk/sessions/verify',
      '/v1/cards',
      '/v1/events/impressions',
    ],
  );
  const challenge = requests[0]!.body;
  assert.deepEqual(challenge.app, {
    platform: 'ios',
    bundle_id: 'app.example.publisher',
    version: '3.2.1',
    build_number: '42',
  });
  assert.equal(
    (challenge.integrity as Record<string, unknown>).device_verification_id,
    'device-verification-id',
  );
  const headers = requests[3]!.headers as Record<string, string>;
  assert.ok(headers['Idempotency-Key']);
});

class FakePlatform implements CrossPromoPlatform {
  async getAppContext() {
    return {
      installation_id: 'install_1',
      platform: 'ios' as const,
      bundle_id: 'app.example.publisher',
      version: '3.2.1',
      build_number: '42',
    };
  }

  async prepareIntegrity(): Promise<IntegrityPreparation> {
    return {
      provider: 'app_attest',
      key_id: 'key_1',
      app_transaction_jws: 'apple.signed.jws',
      device_verification_id: 'device-verification-id',
    };
  }

  async generateEvidence(): Promise<IntegrityEvidence> {
    return {
      provider: 'app_attest',
      key_id: 'key_1',
      payload_base64: 'evidence',
    };
  }

  async openUrl(): Promise<void> {}
  async resetInstallationId(): Promise<void> {}
}
