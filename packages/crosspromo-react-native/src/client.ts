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
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private session?: Session;
  private sessionRequest?: Promise<Session>;

  constructor(
    configuration: CrossPromoConfiguration,
    private readonly platform: CrossPromoPlatform,
    private readonly fetcher: Fetch,
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
      'https://backend-j5mh.onrender.com'
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

  async fetchCard(
    placement: CrossPromoPlacement,
  ): Promise<PromoCardData | null> {
    if (!Object.values(CrossPromoPlacement).includes(placement)) {
      throw new CrossPromoError(
        'placement must be a CrossPromoPlacement option',
      );
    }
    const session = await this.validSession();
    const response = await this.post<{ card: CardWire | null }>(
      '/v1/cards',
      { placement },
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
    await this.post(
      '/v1/events/impressions',
      {
        impression_token: card.impressionToken,
        occurred_at: new Date().toISOString(),
        viewability: {
          visible_fraction: Math.max(0, Math.min(1, visibleFraction)),
          duration_ms: Math.floor(durationMs),
        },
      },
      session.accessToken,
      randomId(),
      true,
    );
  }

  async open(card: PromoCardData): Promise<void> {
    await this.platform.openUrl(card.clickUrl);
  }

  private async validSession(): Promise<Session> {
    if (
      this.session &&
      this.session.status.expiresAt.getTime() - Date.now() > 30_000
    ) {
      return this.session;
    }
    if (this.sessionRequest) return this.sessionRequest;
    this.sessionRequest = this.createSession();
    try {
      this.session = await this.sessionRequest;
      return this.session;
    } finally {
      this.sessionRequest = undefined;
    }
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
      sdk: { name: 'crosspromo-react-native', version: '0.3.4' },
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
