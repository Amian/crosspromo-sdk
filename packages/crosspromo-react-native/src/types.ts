export type CrossPromoEnvironment = 'production' | 'sandbox';

export enum CrossPromoPlacement {
  PostScan = 'post_scan',
  Result = 'result',
  Settings = 'settings',
  EmptyState = 'empty_state',
}

export interface CrossPromoConfiguration {
  appKey: string;
  /** Defaults to sandbox in development builds and production in release builds. */
  environment?: CrossPromoEnvironment;
  /** Intended for local contract tests only. */
  baseUrl?: string;
  requestTimeoutMs?: number;
  /**
   * Everything an ad needs — the session handshake, one card, and its icon — is
   * fetched in the background as soon as `configure` is called, so the first card
   * the app shows appears with no network wait.
   *
   * No placement is needed: a card is identical whichever slot it lands in, so the
   * one held here fills whichever placement appears first, and reports that slot
   * when it is actually seen. Defaults to true; pass `false` to opt out.
   */
  prefetch?: boolean;
}

export interface PromoCardData {
  cardId: string;
  appName: string;
  iconUrl: string;
  tagline: string;
  cta: string;
  clickUrl: string;
  impressionToken: string;
  expiresAt: Date;
}

export interface CrossPromoSessionStatus {
  publisherAppId: string;
  countsEnabled: boolean;
  reason: string | null;
  expiresAt: Date;
}

export interface AppContext {
  platform: 'ios' | 'android';
  bundle_id: string;
  version: string;
  build_number: string;
}

export interface IntegrityEvidence {
  provider: 'app_transaction' | 'play_integrity' | 'none';
  app_transaction_jws: string | null;
}

export interface IconAccentRgb {
  red: number;
  green: number;
  blue: number;
}

export interface CrossPromoPlatform {
  getAppContext(): Promise<AppContext>;
  generateEvidence(input: {
    challenge_base64: string;
    mode: string;
    cloud_project_number?: number;
  }): Promise<IntegrityEvidence>;
  openUrl(url: string): Promise<void>;
  /**
   * Dominant color of the promoted app's icon, used to tint the promo card.
   * Optional: older native builds may not implement it; callers must fall
   * back to a neutral palette.
   */
  extractIconAccent?(url: string): Promise<IconAccentRgb | null>;
}

export type Fetch = (
  input: string,
  init?: RequestInit,
) => Promise<Pick<Response, 'ok' | 'status' | 'text'>>;
