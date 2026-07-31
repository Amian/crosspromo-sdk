import { CrossPromoClient } from './client';
import type { CrossPromoConfiguration } from './types';
export declare class CrossPromo {
    private static configuredClient?;
    /**
     * `configuration.prefetchPlacements` warms the session and one card for each
     * placement given, in the background, so the first card the app shows appears
     * without a network wait. Pass the placements the app actually uses — a
     * prefetched card is held until something asks for it, and anything that
     * fails is fetched on demand.
     *
     * Otherwise, `configuration.warmUpSession` (default true) warms just the
     * session handshake, since that is two of the three requests an ad needs and
     * does not depend on knowing where ads will appear. Both are best effort and
     * neither can throw into the caller.
     */
    static configure(configuration: CrossPromoConfiguration): void;
    static get client(): CrossPromoClient;
}
