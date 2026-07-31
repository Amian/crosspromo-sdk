"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.warmCrossPromoIcon = void 0;
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
const warmCrossPromoIcon = (iconUrl) => {
    if (!iconUrl)
        return;
    try {
        const { Image } = require('react-native');
        Image.prefetch(iconUrl).catch(() => { });
    }
    catch {
        // No react-native runtime (unit tests) or the fetch itself threw synchronously.
        // Either way, nothing to do.
    }
};
exports.warmCrossPromoIcon = warmCrossPromoIcon;
