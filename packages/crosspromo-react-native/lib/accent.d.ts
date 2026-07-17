import type { IconAccentRgb } from './types';
/**
 * Dominant brand color extracted from a promoted app's icon, normalized so
 * every derived color stays rich, legible, and pleasant in both themes.
 * Hue/saturation/value are all in the 0-1 range.
 */
export interface IconAccent {
    hue: number;
    saturation: number;
    value: number;
}
export interface CardPalette {
    surface: string;
    surfaceTinted: string;
    border: string;
    borderTinted: string;
    cta: string;
    ctaTinted: string;
    onCta: string;
    chipBackground: string;
    chipBackgroundTinted: string;
    chipText: string;
    glow: string | null;
    appName: string;
    tagline: string;
    disclosure: string;
}
export declare function accentFromRgb(rgb: IconAccentRgb): IconAccent;
/**
 * Every color the card needs for one theme, both in its neutral (pre-accent)
 * and tinted form so the two can be cross-faded.
 */
export declare function buildPalette(accent: IconAccent | null, darkTheme: boolean): CardPalette;
