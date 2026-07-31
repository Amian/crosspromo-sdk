import { CrossPromoClient } from './client';
import type { CrossPromoConfiguration } from './types';
export declare class CrossPromo {
    private static configuredClient?;
    /**
     * Everything an ad needs — the session handshake, one card, and its icon — is
     * fetched in the background as soon as this is called, so the first card the app
     * shows appears with no network wait.
     *
     * No placement is needed: a card is identical whichever slot it lands in, so the
     * one held here fills whichever placement appears first, and reports that slot
     * when it is actually seen. Pass `prefetch: false` to opt out.
     *
     * Best effort — it cannot throw into the caller, and anything that fails is
     * simply fetched on demand instead.
     */
    static configure(configuration: CrossPromoConfiguration): void;
    static get client(): CrossPromoClient;
}
