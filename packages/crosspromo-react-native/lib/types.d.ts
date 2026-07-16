export type CrossPromoEnvironment = 'production' | 'sandbox';
export declare enum CrossPromoPlacement {
    PostScan = "post_scan",
    Result = "result",
    Settings = "settings",
    EmptyState = "empty_state"
}
export interface CrossPromoConfiguration {
    appKey: string;
    environment?: CrossPromoEnvironment;
    /** Intended for local contract tests only. */
    baseUrl?: string;
    requestTimeoutMs?: number;
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
export interface CrossPromoPlatform {
    getAppContext(): Promise<AppContext>;
    generateEvidence(input: {
        challenge_base64: string;
        mode: string;
        cloud_project_number?: number;
    }): Promise<IntegrityEvidence>;
    openUrl(url: string): Promise<void>;
}
export type Fetch = (input: string, init?: RequestInit) => Promise<Pick<Response, 'ok' | 'status' | 'text'>>;
