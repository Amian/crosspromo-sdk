"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accentFromRgb = accentFromRgb;
exports.buildPalette = buildPalette;
function accentFromRgb(rgb) {
    const { hue, saturation, value } = rgbToHsv(clamp01(rgb.red / 255), clamp01(rgb.green / 255), clamp01(rgb.blue / 255));
    return { hue, saturation: clamp(saturation, 0.55, 0.85), value };
}
/**
 * Every color the card needs for one theme, both in its neutral (pre-accent)
 * and tinted form so the two can be cross-faded.
 */
function buildPalette(accent, darkTheme) {
    const surface = darkTheme ? '#1C1C20' : '#FFFFFF';
    const border = darkTheme ? 'rgba(255,255,255,0.13)' : 'rgba(17,20,24,0.10)';
    const neutralCta = darkTheme ? '#0A84FF' : '#0071E3';
    const shared = {
        appName: darkTheme ? '#F2F3F7' : '#15181D',
        tagline: darkTheme ? 'rgba(235,235,245,0.64)' : 'rgba(24,28,35,0.62)',
        disclosure: darkTheme ? 'rgba(235,235,245,0.42)' : 'rgba(24,28,35,0.45)',
    };
    if (!accent) {
        return {
            ...shared,
            surface,
            surfaceTinted: surface,
            border,
            borderTinted: border,
            cta: neutralCta,
            ctaTinted: neutralCta,
            onCta: '#FFFFFF',
            chipBackground: darkTheme
                ? 'rgba(235,235,245,0.14)'
                : 'rgba(24,28,35,0.08)',
            chipBackgroundTinted: darkTheme
                ? 'rgba(235,235,245,0.14)'
                : 'rgba(24,28,35,0.08)',
            chipText: shared.tagline,
            glow: null,
        };
    }
    const { hue, saturation, value } = accent;
    const softSaturation = Math.min(saturation, 0.8);
    const cta = darkTheme
        ? hsvToHex(hue, Math.min(saturation, 0.75), clamp(value, 0.62, 0.84))
        : hsvToHex(hue, saturation, clamp(value, 0.5, 0.72));
    const wash = darkTheme
        ? blend(hsvToRgbTuple(hue, softSaturation, 0.72), 0.13, [28, 28, 32])
        : blend(hsvToRgbTuple(hue, softSaturation, 0.56), 0.06, [255, 255, 255]);
    return {
        ...shared,
        surface,
        surfaceTinted: wash,
        border,
        borderTinted: darkTheme
            ? hsvToRgba(hue, softSaturation, 0.78, 0.38)
            : hsvToRgba(hue, softSaturation, 0.5, 0.26),
        cta: neutralCta,
        ctaTinted: cta,
        onCta: relativeLuminance(hexToRgbTuple(cta)) > 0.4 ? '#12161C' : '#FFFFFF',
        chipBackground: darkTheme
            ? 'rgba(235,235,245,0.14)'
            : 'rgba(24,28,35,0.08)',
        chipBackgroundTinted: darkTheme
            ? hsvToRgba(hue, softSaturation, 0.75, 0.24)
            : hsvToRgba(hue, softSaturation, 0.55, 0.14),
        chipText: darkTheme
            ? hsvToHex(hue, softSaturation, 0.88)
            : hsvToHex(hue, softSaturation, 0.42),
        glow: darkTheme
            ? hsvToRgba(hue, saturation, 0.72, 0.5)
            : hsvToRgba(hue, saturation, 0.6, 0.32),
    };
}
function clamp(input, low, high) {
    return Math.min(high, Math.max(low, input));
}
function clamp01(input) {
    return clamp(input, 0, 1);
}
function rgbToHsv(red, green, blue) {
    const value = Math.max(red, green, blue);
    const chroma = value - Math.min(red, green, blue);
    const saturation = value === 0 ? 0 : chroma / value;
    let hue = 0;
    if (chroma > 0) {
        if (value === red) {
            hue = ((green - blue) / chroma) % 6;
        }
        else if (value === green) {
            hue = (blue - red) / chroma + 2;
        }
        else {
            hue = (red - green) / chroma + 4;
        }
        hue /= 6;
        if (hue < 0)
            hue += 1;
    }
    return { hue, saturation, value };
}
function hsvToRgbTuple(hue, saturation, value) {
    const sector = (hue % 1) * 6;
    const chroma = value * saturation;
    const secondary = chroma * (1 - Math.abs((sector % 2) - 1));
    const base = value - chroma;
    let rgb;
    if (sector < 1)
        rgb = [chroma, secondary, 0];
    else if (sector < 2)
        rgb = [secondary, chroma, 0];
    else if (sector < 3)
        rgb = [0, chroma, secondary];
    else if (sector < 4)
        rgb = [0, secondary, chroma];
    else if (sector < 5)
        rgb = [secondary, 0, chroma];
    else
        rgb = [chroma, 0, secondary];
    return [
        Math.round((rgb[0] + base) * 255),
        Math.round((rgb[1] + base) * 255),
        Math.round((rgb[2] + base) * 255),
    ];
}
function hsvToHex(hue, saturation, value) {
    const [red, green, blue] = hsvToRgbTuple(hue, saturation, value);
    const channel = (component) => component.toString(16).padStart(2, '0');
    return `#${channel(red)}${channel(green)}${channel(blue)}`.toUpperCase();
}
function hsvToRgba(hue, saturation, value, alpha) {
    const [red, green, blue] = hsvToRgbTuple(hue, saturation, value);
    return `rgba(${red},${green},${blue},${alpha})`;
}
function hexToRgbTuple(hex) {
    return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16),
    ];
}
function blend(top, alpha, base) {
    const mix = (topChannel, baseChannel) => Math.round(topChannel * alpha + baseChannel * (1 - alpha));
    return `rgb(${mix(top[0], base[0])},${mix(top[1], base[1])},${mix(top[2], base[2])})`;
}
function relativeLuminance([red, green, blue]) {
    const linearize = (component) => {
        const channel = component / 255;
        return channel <= 0.04045
            ? channel / 12.92
            : Math.pow((channel + 0.055) / 1.055, 2.4);
    };
    return (0.2126 * linearize(red) +
        0.7152 * linearize(green) +
        0.0722 * linearize(blue));
}
