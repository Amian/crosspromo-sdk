import type { CrossPromoConfiguration, CrossPromoPlatform, CrossPromoSessionStatus, Fetch, PromoCardData } from './types';
export declare class CrossPromoError extends Error {
    readonly statusCode?: number | undefined;
    constructor(message: string, statusCode?: number | undefined);
}
export declare class CrossPromoClient {
    private readonly platform;
    private readonly fetcher;
    private readonly baseUrl;
    private readonly timeoutMs;
    private session?;
    private sessionRequest?;
    constructor(configuration: CrossPromoConfiguration, platform: CrossPromoPlatform, fetcher: Fetch);
    private readonly configuration;
    sessionStatus(): Promise<CrossPromoSessionStatus>;
    fetchCard(placement: string): Promise<PromoCardData | null>;
    recordImpression(card: PromoCardData, visibleFraction: number, durationMs: number): Promise<void>;
    open(card: PromoCardData): Promise<void>;
    resetInstallationId(): Promise<void>;
    private validSession;
    private createSession;
    private post;
}
