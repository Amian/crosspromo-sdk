import type { CrossPromoIconWarmer } from './iconWarmer';
import { CrossPromoPlacement } from './types';
import type { CrossPromoConfiguration, CrossPromoPlatform, CrossPromoSessionStatus, Fetch, PromoCardData } from './types';
export declare const resolveEnvironment: (environment: CrossPromoConfiguration["environment"], isDevelopment?: boolean) => "production" | "sandbox";
export declare class CrossPromoError extends Error {
    readonly statusCode?: number | undefined;
    constructor(message: string, statusCode?: number | undefined);
}
export declare class CrossPromoClient {
    private readonly platform;
    private readonly fetcher;
    private readonly iconWarmer;
    /**
     * A session this close to expiring is renewed before it is handed out, so a
     * request can never be signed with a token that dies mid-flight.
     */
    private static readonly sessionMinimumRemainingMs;
    /**
     * A still-valid session with less than this left is renewed in the background,
     * so an ad request practically never waits for the three-call handshake.
     */
    private static readonly sessionRefreshMarginMs;
    /**
     * A prefetched card has to outlive the viewability window it is about to be
     * measured against, so one that is nearly expired is discarded rather than
     * shown and then failing to record.
     */
    private static readonly cardMinimumRemainingMs;
    private readonly baseUrl;
    private readonly timeoutMs;
    private session?;
    private sessionRequest?;
    /**
     * Cards fetched ahead of being needed, keyed by placement.
     *
     * Cards are single use: each carries its own impression token, and the backend
     * treats a repeated token as a replay. Handing one card to two placements would
     * therefore silently drop the second impression, so taking a prefetched card
     * removes it from here.
     */
    private readonly prefetched;
    private readonly prefetchRequests;
    constructor(configuration: CrossPromoConfiguration, platform: CrossPromoPlatform, fetcher: Fetch, iconWarmer?: CrossPromoIconWarmer);
    private readonly configuration;
    sessionStatus(): Promise<CrossPromoSessionStatus>;
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
    prefetch(placement: CrossPromoPlacement): Promise<void>;
    /**
     * Warms only the session handshake, for apps that want the credential ready
     * without holding a card that could go stale.
     */
    warmUp(): Promise<void>;
    private runPrefetch;
    fetchCard(placement: CrossPromoPlacement): Promise<PromoCardData | null>;
    private takePrefetched;
    private requestCard;
    recordImpression(card: PromoCardData, visibleFraction: number, durationMs: number): Promise<void>;
    open(card: PromoCardData): Promise<void>;
    private validSession;
    private startSession;
    private renewSessionInBackground;
    private createSession;
    private post;
}
