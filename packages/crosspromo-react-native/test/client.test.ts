import assert from 'node:assert/strict';
import test from 'node:test';

import { CrossPromoClient, CrossPromoError, resolveEnvironment } from '../src/client';
import { CrossPromoPlacement } from '../src/types';
import type {
  CrossPromoConfiguration,
  CrossPromoPlatform,
  Fetch,
  IntegrityEvidence,
} from '../src/types';

test('automatically selects the build environment and respects overrides', () => {
  assert.equal(resolveEnvironment(undefined, true), 'sandbox');
  assert.equal(resolveEnvironment(undefined, false), 'production');
  assert.equal(resolveEnvironment('sandbox', false), 'sandbox');
  assert.equal(resolveEnvironment('production', true), 'production');
});

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
    version: '0.3.4',
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

test('a prefetched card is served without any further network call', async () => {
  const transport = new FakeTransport();
  const client = newClient(transport);

  await client.prefetch(CrossPromoPlacement.PostScan);
  assert.deepEqual(
    transport.requests.map((r) => r.path),
    ['/v1/sdk/sessions/challenge', '/v1/sdk/sessions/verify', '/v1/cards'],
  );

  const card = await client.fetchCard(CrossPromoPlacement.PostScan);
  assert.equal(card?.cardId, 'c_1');
  // Showing a prefetched card must not touch the network.
  assert.equal(transport.requests.length, 3);
});

test('a prefetched card is single use, because its impression token is', async () => {
  const transport = new FakeTransport();
  const client = newClient(transport);

  await client.prefetch(CrossPromoPlacement.PostScan);
  const first = await client.fetchCard(CrossPromoPlacement.PostScan);
  const second = await client.fetchCard(CrossPromoPlacement.PostScan);

  assert.equal(first?.cardId, 'c_1');
  // The second card must be a fresh one.
  assert.equal(second?.cardId, 'c_2');
  assert.notEqual(first?.impressionToken, second?.impressionToken);
  assert.equal(transport.cardRequestCount, 2);
});

test('a prefetched card for another placement is not reused', async () => {
  const transport = new FakeTransport();
  const client = newClient(transport);

  await client.prefetch(CrossPromoPlacement.PostScan);
  const card = await client.fetchCard(CrossPromoPlacement.Settings);

  assert.equal(card?.cardId, 'c_2');
  assert.equal(transport.cardRequestCount, 2);
  assert.equal(transport.requests[transport.requests.length - 1]?.body.placement, 'settings');
});

test('a prefetched card too close to expiry is discarded, not shown', async () => {
  // Below the client's freshness margin: it could expire before the viewability
  // window it is about to be measured against completes.
  const transport = new FakeTransport({ cardLifetimeMs: 5_000 });
  const client = newClient(transport);

  await client.prefetch(CrossPromoPlacement.PostScan);
  assert.equal(transport.cardRequestCount, 1);

  const card = await client.fetchCard(CrossPromoPlacement.PostScan);
  // The stale card is refetched.
  assert.equal(transport.cardRequestCount, 2);
  assert.equal(card?.cardId, 'c_2');
});

test('a card requested while a prefetch is in flight reuses that request', async () => {
  let resolveGate!: () => void;
  const gate = new Promise<void>((resolve) => {
    resolveGate = resolve;
  });
  const transport = new FakeTransport({ cardGate: gate });
  const client = newClient(transport);

  const warming = client.prefetch(CrossPromoPlacement.PostScan);
  const pending = client.fetchCard(CrossPromoPlacement.PostScan);
  resolveGate();
  const card = await pending;
  await warming;

  assert.equal(card?.cardId, 'c_1');
  // A mount during prefetch must not start a second card request.
  assert.equal(transport.cardRequestCount, 1);
});

test('a failed prefetch stays silent and the card is fetched on demand', async () => {
  const transport = new FakeTransport({ failCards: true });
  const client = newClient(transport);

  // Must not throw: nothing was on screen when this ran.
  await client.prefetch(CrossPromoPlacement.PostScan);

  await assert.rejects(
    client.fetchCard(CrossPromoPlacement.PostScan),
    CrossPromoError,
  );
  assert.equal(transport.cardRequestCount, 2);
});

test('prefetching also warms the card icon', async () => {
  const transport = new FakeTransport();
  const warmed: string[] = [];
  const client = newClient(transport, (iconUrl) => warmed.push(iconUrl));

  await client.prefetch(CrossPromoPlacement.PostScan);

  assert.deepEqual(warmed, ['https://cdn.example/icon.png']);
});

test('a prefetch that returns no card warms nothing', async () => {
  const transport = new FakeTransport({ failCards: true });
  const warmed: string[] = [];
  const client = newClient(transport, (iconUrl) => warmed.push(iconUrl));

  await client.prefetch(CrossPromoPlacement.PostScan);

  assert.deepEqual(warmed, []);
});

test('an icon warmer that throws cannot break the prefetch', async () => {
  // The warmer touches the image cache, which needs a runtime that may not exist
  // wherever configure() was called. A failure there must not lose the card.
  const transport = new FakeTransport();
  const client = newClient(transport, () => {
    throw new Error('no image cache');
  });

  await client.prefetch(CrossPromoPlacement.PostScan);
  const card = await client.fetchCard(CrossPromoPlacement.PostScan);

  assert.equal(card?.cardId, 'c_1');
  assert.equal(transport.cardRequestCount, 1);
});

function newClient(
  transport: FakeTransport,
  iconWarmer?: (iconUrl: string) => void,
): CrossPromoClient {
  const configuration: CrossPromoConfiguration = {
    appKey: 'cp_live_example',
    baseUrl: 'https://example.test',
  };
  return new CrossPromoClient(
    configuration,
    new FakePlatform(),
    transport.fetch,
    iconWarmer ?? (() => {}),
  );
}

interface RequestRecord {
  path: string;
  body: Record<string, unknown>;
}

interface FakeTransportOptions {
  /** How long each served card stays valid. Defaults to the far future. */
  cardLifetimeMs?: number;
  /**
   * When set, every `/v1/cards` response waits on this before completing, so a
   * test can observe behaviour while a card request is still in flight.
   */
  cardGate?: Promise<void>;
  /** Makes `/v1/cards` fail, to prove a failed prefetch stays invisible. */
  failCards?: boolean;
}

class FakeTransport {
  readonly requests: RequestRecord[] = [];
  private cardsServed = 0;

  constructor(private readonly options: FakeTransportOptions = {}) {}

  get cardRequestCount(): number {
    return this.requests.filter((r) => r.path === '/v1/cards').length;
  }

  fetch: Fetch = async (url, init) => {
    const path = new URL(url).pathname;
    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    this.requests.push({ path, body });

    if (path === '/v1/cards') {
      if (this.options.cardGate) await this.options.cardGate;
      if (this.options.failCards) {
        return { ok: false, status: 500, text: async () => '{}' };
      }
    }

    switch (path) {
      case '/v1/sdk/sessions/challenge':
        return jsonResponse({
          session_id: 's_1',
          challenge_base64: 'aGVsbG8=',
          integrity_mode: 'app_transaction',
        });
      case '/v1/sdk/sessions/verify':
        return jsonResponse({
          access_token: 'token',
          publisher_app_id: 'app_1',
          counts_enabled: true,
          reason: null,
          expires_at: '2099-01-01T00:00:00Z',
        });
      case '/v1/cards': {
        this.cardsServed += 1;
        const expiresAt =
          this.options.cardLifetimeMs === undefined
            ? '2099-01-01T00:00:00Z'
            : new Date(Date.now() + this.options.cardLifetimeMs).toISOString();
        return jsonResponse({
          card: {
            card_id: `c_${this.cardsServed}`,
            app_name: 'Rock Finder',
            icon_url: 'https://cdn.example/icon.png',
            tagline: 'Find every rock',
            cta: 'Get',
            click_url: 'https://go.example/c/1',
            impression_token: `imp_${this.cardsServed}`,
            expires_at: expiresAt,
          },
        });
      }
      case '/v1/events/impressions':
        return jsonResponse(undefined);
      default:
        throw new Error(`Unexpected path ${path}`);
    }
  };
}

function jsonResponse(body: unknown): { ok: true; status: 200; text: () => Promise<string> } {
  return {
    ok: true,
    status: 200,
    text: async () => (body === undefined ? '' : JSON.stringify(body)),
  };
}

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
