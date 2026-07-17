import assert from 'node:assert/strict';
import test from 'node:test';

import { CrossPromoClient } from '../src/client';
import { CrossPromoPlacement } from '../src/types';
import type {
  CrossPromoPlatform,
  Fetch,
  IntegrityEvidence,
} from '../src/types';

test('sends app identity and only reports qualified impressions', async () => {
  const requests: Array<{ path: string; body: Record<string, unknown>; headers: HeadersInit }> = [];
  const responses: Record<string, unknown> = {
    '/v1/sdk/sessions/challenge': {
      session_id: 's_1',
      challenge_base64: 'aGVsbG8=',
      integrity_mode: 'app_transaction',
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
    { appKey: 'cp_live_example', baseUrl: 'https://example.test' },
    new FakePlatform(),
    fetcher,
  );

  await assert.rejects(
    client.fetchCard('post scan' as CrossPromoPlacement),
    /CrossPromoPlacement option/,
  );
  assert.equal(requests.length, 0);
  const card = await client.fetchCard(CrossPromoPlacement.PostScan);
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
  assert.equal(challenge.environment, 'production');
  assert.deepEqual(challenge.app, {
    platform: 'ios',
    bundle_id: 'app.example.publisher',
    version: '3.2.1',
    build_number: '42',
  });
  assert.deepEqual(challenge.sdk, {
    name: 'crosspromo-react-native',
    version: '0.3.3',
  });
  assert.equal(challenge.installation_id, undefined);
  assert.equal(challenge.locale, undefined);
  assert.equal(challenge.integrity, undefined);
  const verifyEvidence = requests[1]!.body.evidence as Record<string, unknown>;
  assert.equal(verifyEvidence.provider, 'app_transaction');
  assert.equal(verifyEvidence.app_transaction_jws, 'apple.signed.jws');
  assert.equal(requests[2]!.body.placement, 'post_scan');
  const headers = requests[3]!.headers as Record<string, string>;
  assert.ok(headers['Idempotency-Key']);
});

class FakePlatform implements CrossPromoPlatform {
  async getAppContext() {
    return {
      platform: 'ios' as const,
      bundle_id: 'app.example.publisher',
      version: '3.2.1',
      build_number: '42',
    };
  }

  async generateEvidence(): Promise<IntegrityEvidence> {
    return {
      provider: 'app_transaction',
      app_transaction_jws: 'apple.signed.jws',
    };
  }

  async openUrl(): Promise<void> {}
}
