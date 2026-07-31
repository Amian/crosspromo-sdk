/**
 * Pulls a card's icon into the image cache before the card is shown.
 *
 * Prefetching the card JSON alone still leaves the icon downloading at the moment
 * the card appears, so it fades in a beat late. Warming it here means the bytes are
 * already cached and waiting.
 */
export type CrossPromoIconWarmer = (iconUrl: string) => void;
/**
 * Resolves through the same cache the card's `<Image>` reads from (see
 * PromoCard.tsx), so the card hits the cache rather than the network.
 *
 * Deliberately silent and non-blocking: this runs when nothing is on screen, so a
 * failure here must never surface. The card falls back to loading the icon itself,
 * which is exactly what it did before. `react-native` is required lazily, inside the
 * try, because it is not present wherever plain unit tests run, and a missing
 * module must not throw.
 */
export declare const warmCrossPromoIcon: CrossPromoIconWarmer;
