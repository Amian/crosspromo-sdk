import { warmCrossPromoIcon } from './iconWarmer';
import type { CrossPromoIconWarmer } from './iconWarmer';
import { CrossPromoPlacement } from './types';
import type {
  CrossPromoConfiguration,
  CrossPromoPlatform,
  CrossPromoSessionStatus,
  Fetch,
  PromoCardData,
} from './types';

interface Session {
  accessToken: string;
  status: CrossPromoSessionStatus;
}

interface CardWire {
  card_id: string;
  app_name: string;
  icon_url: string;
  tagline: string;
  cta: string;
  click_url: string;
  impression_token: string;
  expires_at: string;
}

export const resolveEnvironment = (
  environment: CrossPromoConfiguration['environment'],
  isDevelopment = typeof __DEV__ !== 'undefined' && __DEV__,
): 'production' | 'sandbox' =>
  environment ?? (isDevelopment ? 'sandbox' : 'production');

export class CrossPromoError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
  ) {
    super(message);
    this.name = 'CrossPromoError';
  }
}

export class CrossPromoClient {
  /**
   * A session this close to expiring is renewed before it is handed out, so a
   * request can never be signed with a token that dies mid-flight.
   */
  private static readonly sessionMinimumRemainingMs = 30_000;

  /**
   * A still-valid session with less than this left is renewed in the background,
   * so an ad request practically never waits for the three-call handshake.
   */
  private static readonly sessionRefreshMarginMs = 120_000;

  /**
   * A prefetched card has to outlive the viewability window it is about to be
   * measured against, so one that is nearly expired is discarded rather than
   * shown and then failing to record.
   */
  private static readonly cardMinimumRemainingMs = 30_000;

  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private session?: Session;
  private sessionRequest?: Promise<Session>;

  /**
   * One card fetched ahead of being needed.
   *
   * A card is identical whichever slot it lands in — placement never affects which
   * ad the backend picks — so a single held card can fill whichever placement
   * appears first. It is single use, though — one card is one ad — so taking it
   * removes it.
   */
  private prefetchedCard?: PromoCardData;
  private prefetchRequest?: Promise<void>;

  /**
   * Which slot each card was handed to, so its impression and click can report
   * where it was actually shown. Bounded: cards are short-lived and only a couple
   * are ever in flight.
   */
  private readonly placementByCard = new Map<string, string>();

  constructor(
    configuration: CrossPromoConfiguration,
    private readonly platform: CrossPromoPlatform,
    private readonly fetcher: Fetch,
    private readonly iconWarmer: CrossPromoIconWarmer = warmCrossPromoIcon,
  ) {
    if (
      !configuration.appKey.startsWith('cp_live_') &&
      !configuration.appKey.startsWith('cpn_live_')
    ) {
      throw new CrossPromoError(
        'appKey must be the key shown in your CrossPromo dashboard',
      );
    }
    this.configuration = configuration;
    this.baseUrl = (
      configuration.baseUrl ??
      'https://api.promotethatapp.com'
    ).replace(/\/$/, '');
    this.timeoutMs = configuration.requestTimeoutMs ?? 10_000;
    if (this.timeoutMs <= 0) {
      throw new CrossPromoError('requestTimeoutMs must be positive');
    }
  }

  private readonly configuration: CrossPromoConfiguration;

  async sessionStatus(): Promise<CrossPromoSessionStatus> {
    return (await this.validSession()).status;
  }

  /**
   * Does the slow part of showing an ad before there is anywhere to show it: the
   * session handshake and one card fetch. Call it at app start, or as soon as you
   * know a placement is coming, and the matching {@link fetchCard} returns
   * immediately.
   *
   * Best effort by design — failures are swallowed, because a prefetch that did
   * not work must not surface as an error at a point where the app was not even
   * showing an ad. The card is simply fetched on demand instead.
   *
   * Safe to call repeatedly: concurrent calls for one placement share a single
   * fetch, and a placement that already holds a fresh card does nothing.
   */
  prefetch(): Promise<void> {
    const inflight = this.prefetchRequest;
    if (inflight) return inflight;
    if (this.prefetchedCard) return Promise.resolve();
    const request = this.runPrefetch();
    this.prefetchRequest = request;
    return request;
  }

  /**
   * Warms only the session handshake, for apps that want the credential ready
   * without holding a card that could go stale.
   */
  async warmUp(): Promise<void> {
    try {
      await this.validSession();
    } catch {
      // Best effort, exactly like prefetch.
    }
  }

  private async runPrefetch(): Promise<void> {
    try {
      const card = await this.requestCard();
      if (card) {
        this.prefetchedCard = card;
        // Pull the icon in too. Without this the card text would appear instantly
        // and the icon would still fade in a beat later.
        this.iconWarmer(card.iconUrl);
      }
    } catch {
      // Swallowed: see prefetch's contract.
    } finally {
      this.prefetchRequest = undefined;
    }
  }

  async fetchCard(
    placement: CrossPromoPlacement,
  ): Promise<PromoCardData | null> {
    if (!Object.values(CrossPromoPlacement).includes(placement)) {
      throw new CrossPromoError(
        'placement must be a CrossPromoPlacement option',
      );
    }
    const ready = this.takePrefetched();
    if (ready) return this.assign(ready, placement);

    // A prefetch already on the wire: wait for it rather than starting a second
    // identical request and wasting the impression the first one is holding.
    const inflight = this.prefetchRequest;
    if (inflight) {
      await inflight;
      const arrived = this.takePrefetched();
      if (arrived) return this.assign(arrived, placement);
    }
    const fresh = await this.requestCard();
    return fresh ? this.assign(fresh, placement) : null;
  }

  private takePrefetched(): PromoCardData | null {
    const held = this.prefetchedCard;
    if (!held) return null;
    this.prefetchedCard = undefined;
    const remaining = held.expiresAt.getTime() - Date.now();
    return remaining > CrossPromoClient.cardMinimumRemainingMs ? held : null;
  }

  /**
   * Records which slot this card went to, so the impression and click that follow
   * can say where it was really shown.
   */
  private assign(
    card: PromoCardData,
    placement: CrossPromoPlacement,
  ): PromoCardData {
    if (this.placementByCard.size >= 32) {
      const oldest = this.placementByCard.keys().next().value;
      if (oldest !== undefined) this.placementByCard.delete(oldest);
    }
    this.placementByCard.set(card.cardId, placement);
    return card;
  }

  private async requestCard(): Promise<PromoCardData | null> {
    const session = await this.validSession();
    // No placement: the backend returns the same card either way, and sending one
    // here would tie this card to a slot before we know where it will be shown.
    const response = await this.post<{ card: CardWire | null }>(
      '/v1/cards',
      {},
      session.accessToken,
    );
    return response.card ? cardFromWire(response.card) : null;
  }

  async recordImpression(
    card: PromoCardData,
    visibleFraction: number,
    durationMs: number,
  ): Promise<void> {
    if (visibleFraction < 0.5 || durationMs < 1_000) return;
    const session = await this.validSession();
    const placement = this.placementByCard.get(card.cardId);
    await this.post(
      '/v1/events/impressions',
      {
        impression_token: card.impressionToken,
        occurred_at: new Date().toISOString(),
        viewability: {
          visible_fraction: Math.max(0, Math.min(1, visibleFraction)),
          duration_ms: Math.floor(durationMs),
        },
        ...(placement !== undefined ? { placement } : undefined),
      },
      session.accessToken,
      randomId(),
      true,
    );
  }

  async open(card: PromoCardData): Promise<void> {
    // A click is a plain redirect with no body, so the slot travels on the link.
    const placement = this.placementByCard.get(card.cardId);
    const url =
      placement === undefined
        ? card.clickUrl
        : appendQueryParam(card.clickUrl, 'placement', placement);
    await this.platform.openUrl(url);
  }

  private async validSession(): Promise<Session> {
    if (this.session) {
      const remaining = this.session.status.expiresAt.getTime() - Date.now();
      if (remaining > CrossPromoClient.sessionMinimumRemainingMs) {
        if (remaining < CrossPromoClient.sessionRefreshMarginMs) {
          // Still usable, but close enough to expiry that the next ad would have
          // paid for a fresh handshake. Renew behind this request and answer it
          // with the token we already hold.
          this.renewSessionInBackground();
        }
        return this.session;
      }
    }
    return this.startSession();
  }

  private async startSession(): Promise<Session> {
    if (this.sessionRequest) return this.sessionRequest;
    this.sessionRequest = this.createSession();
    try {
      this.session = await this.sessionRequest;
      return this.session;
    } finally {
      this.sessionRequest = undefined;
    }
  }

  private renewSessionInBackground(): void {
    if (this.sessionRequest) return;
    void this.startSession().catch(() => {});
  }

  private async createSession(): Promise<Session> {
    const app = await this.platform.getAppContext();
    const challenge = await this.post<{
      session_id: string;
      challenge_base64: string;
      integrity_mode: string;
      cloud_project_number?: number;
    }>('/v1/sdk/sessions/challenge', {
      app_key: this.configuration.appKey,
      environment: resolveEnvironment(this.configuration.environment),
      app: {
        platform: app.platform,
        bundle_id: app.bundle_id,
        version: app.version,
        build_number: app.build_number,
      },
      sdk: { name: 'crosspromo-react-native', version: '0.3.7' },
    });
    const evidence = await this.platform.generateEvidence({
      challenge_base64: challenge.challenge_base64,
      mode: challenge.integrity_mode,
      cloud_project_number: challenge.cloud_project_number,
    });
    const verified = await this.post<{
      access_token: string;
      publisher_app_id: string;
      counts_enabled: boolean;
      reason: string | null;
      expires_at: string;
    }>('/v1/sdk/sessions/verify', {
      session_id: challenge.session_id,
      evidence,
    });
    return {
      accessToken: verified.access_token,
      status: {
        publisherAppId: verified.publisher_app_id,
        countsEnabled: verified.counts_enabled,
        reason: verified.reason,
        expiresAt: new Date(verified.expires_at),
      },
    };
  }

  private async post<T>(
    path: string,
    body: Record<string, unknown>,
    bearerToken?: string,
    idempotencyKey?: string,
    allowEmpty = false,
  ): Promise<T> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetcher(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(bearerToken
            ? { Authorization: `Bearer ${bearerToken}` }
            : undefined),
          ...(idempotencyKey
            ? { 'Idempotency-Key': idempotencyKey }
            : undefined),
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      const text = await response.text();
      if (!response.ok) {
        let message = 'Request failed';
        try {
          const decoded = JSON.parse(text) as {
            error?: { message?: string };
          };
          message = decoded.error?.message ?? message;
        } catch {
          // A proxy may have returned a non-JSON error page.
        }
        throw new CrossPromoError(message, response.status);
      }
      if (!text && allowEmpty) return undefined as T;
      try {
        return JSON.parse(text) as T;
      } catch {
        throw new CrossPromoError('The API returned invalid JSON');
      }
    } finally {
      clearTimeout(timeout);
    }
  }
}

function cardFromWire(card: CardWire): PromoCardData {
  return {
    cardId: card.card_id,
    appName: card.app_name,
    iconUrl: card.icon_url,
    tagline: card.tagline,
    cta: card.cta,
    clickUrl: card.click_url,
    impressionToken: card.impression_token,
    expiresAt: new Date(card.expires_at),
  };
}

function randomId(): string {
  return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;
}

// Appended rather than parsed and rebuilt: Hermes has no global URL without a
// polyfill the SDK should not have to require, and appending is all that is
// needed to preserve whatever query params clickUrl already carries.
function appendQueryParam(url: string, key: string, value: string): string {
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
}
