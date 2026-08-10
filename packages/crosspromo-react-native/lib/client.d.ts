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
     * One card fetched ahead of being needed.
     *
     * A card is identical whichever slot it lands in — placement never affects which
     * ad the backend picks — so a single held card can fill whichever placement
     * appears first. It is single use, though — one card is one ad — so taking it
     * removes it.
     */
    private prefetchedCard?;
    private prefetchRequest?;
    /**
     * Which slot each card was handed to, so its impression and click can report
     * where it was actually shown. Bounded: cards are short-lived and only a couple
     * are ever in flight.
     */
    private readonly placementByCard;
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
    prefetch(): Promise<void>;
    /**
     * Warms only the session handshake, for apps that want the credential ready
     * without holding a card that could go stale.
     */
    warmUp(): Promise<void>;
    private runPrefetch;
    fetchCard(placement: CrossPromoPlacement): Promise<PromoCardData | null>;
    private takePrefetched;
    /**
     * Records which slot this card went to, so the impression and click that follow
     * can say where it was really shown.
     */
    private assign;
    private requestCard;
    recordImpression(card: PromoCardData, visibleFraction: number, durationMs: number): Promise<void>;
    open(card: PromoCardData): Promise<void>;
    private validSession;
    private startSession;
    private renewSessionInBackground;
    private createSession;
    private post;
}
