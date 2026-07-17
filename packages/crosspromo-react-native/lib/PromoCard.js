"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PromoCard = PromoCard;
exports.CrossPromoImpressionView = CrossPromoImpressionView;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const react_native_1 = require("react-native");
const accent_1 = require("./accent");
const CrossPromo_1 = require("./CrossPromo");
const native_1 = require("./native");
function PromoCard({ placement, style, onError, onLoaded, }) {
    const [card, setCard] = (0, react_1.useState)(null);
    const [accent, setAccent] = (0, react_1.useState)(null);
    const scheme = (0, react_native_1.useColorScheme)();
    const darkTheme = scheme === 'dark';
    const entrance = (0, react_1.useRef)(new react_native_1.Animated.Value(0)).current;
    const tint = (0, react_1.useRef)(new react_native_1.Animated.Value(0)).current;
    const reduceMotionRef = (0, react_1.useRef)(false);
    const onErrorRef = (0, react_1.useRef)(onError);
    const onLoadedRef = (0, react_1.useRef)(onLoaded);
    onErrorRef.current = onError;
    onLoadedRef.current = onLoaded;
    (0, react_1.useEffect)(() => {
        let active = true;
        react_native_1.AccessibilityInfo.isReduceMotionEnabled()
            .then((enabled) => {
            if (active)
                reduceMotionRef.current = enabled;
        })
            .catch(() => { });
        return () => {
            active = false;
        };
    }, []);
    (0, react_1.useEffect)(() => {
        let active = true;
        setCard(null);
        setAccent(null);
        entrance.setValue(0);
        tint.setValue(0);
        CrossPromo_1.CrossPromo.client
            .fetchCard(placement)
            .then((value) => {
            if (!active)
                return;
            setCard(value);
            onLoadedRef.current?.(value);
            if (value) {
                if (reduceMotionRef.current) {
                    entrance.setValue(1);
                }
                else {
                    react_native_1.Animated.timing(entrance, {
                        toValue: 1,
                        duration: 420,
                        easing: react_native_1.Easing.out(react_native_1.Easing.cubic),
                        useNativeDriver: true,
                    }).start();
                }
            }
        })
            .catch((error) => {
            if (active)
                onErrorRef.current?.(error);
        });
        return () => {
            active = false;
        };
    }, [placement, entrance, tint]);
    (0, react_1.useEffect)(() => {
        if (!card)
            return;
        const extract = native_1.NativeCrossPromoPlatform.extractIconAccent;
        if (typeof extract !== 'function')
            return;
        let active = true;
        extract(card.iconUrl)
            .then((rgb) => {
            if (!active || !rgb)
                return;
            setAccent((0, accent_1.accentFromRgb)(rgb));
            if (reduceMotionRef.current) {
                tint.setValue(1);
            }
            else {
                react_native_1.Animated.timing(tint, {
                    toValue: 1,
                    duration: 320,
                    easing: react_native_1.Easing.out(react_native_1.Easing.quad),
                    useNativeDriver: false,
                }).start();
            }
        })
            .catch(() => { });
        return () => {
            active = false;
        };
    }, [card, tint]);
    if (!card)
        return null;
    const palette = (0, accent_1.buildPalette)(accent, darkTheme);
    const crossFade = (from, to) => tint.interpolate({ inputRange: [0, 1], outputRange: [from, to] });
    const surface = crossFade(palette.surface, palette.surfaceTinted);
    const border = crossFade(palette.border, palette.borderTinted);
    const ctaBackground = crossFade(palette.cta, palette.ctaTinted);
    const chipBackground = crossFade(palette.chipBackground, palette.chipBackgroundTinted);
    return ((0, jsx_runtime_1.jsx)(CrossPromoImpressionView, { card: card, style: style, children: (0, jsx_runtime_1.jsx)(react_native_1.Animated.View, { style: {
                opacity: entrance,
                transform: [
                    {
                        translateY: entrance.interpolate({
                            inputRange: [0, 1],
                            outputRange: [10, 0],
                        }),
                    },
                ],
            }, children: (0, jsx_runtime_1.jsx)(react_native_1.Pressable, { accessibilityRole: "button", accessibilityLabel: `Ad. ${card.appName}. ${card.tagline}`, onPress: () => void CrossPromo_1.CrossPromo.client.open(card), style: ({ pressed }) => [
                    pressed && styles.pressed,
                    pressed && { transform: [{ scale: 0.98 }] },
                ], children: (0, jsx_runtime_1.jsxs)(react_native_1.Animated.View, { style: [
                        styles.card,
                        darkTheme ? styles.cardDark : styles.cardLight,
                        { backgroundColor: surface, borderColor: border },
                    ], children: [(0, jsx_runtime_1.jsx)(react_native_1.View, { style: [
                                styles.iconHalo,
                                palette.glow !== null && {
                                    shadowColor: palette.glow,
                                    shadowOpacity: 1,
                                    shadowRadius: 9,
                                    shadowOffset: { width: 0, height: 3 },
                                },
                            ], children: (0, jsx_runtime_1.jsx)(react_native_1.Image, { source: { uri: card.iconUrl }, style: [
                                    styles.icon,
                                    darkTheme ? styles.iconDark : styles.iconLight,
                                ] }) }), (0, jsx_runtime_1.jsxs)(react_native_1.View, { style: styles.copy, children: [(0, jsx_runtime_1.jsx)(react_native_1.Text, { style: [styles.appName, { color: palette.appName }], numberOfLines: 1, children: card.appName }), (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: [styles.tagline, { color: palette.tagline }], numberOfLines: 2, children: card.tagline }), (0, jsx_runtime_1.jsxs)(react_native_1.View, { style: styles.disclosureRow, children: [(0, jsx_runtime_1.jsx)(react_native_1.Animated.View, { style: [styles.adChip, { backgroundColor: chipBackground }], children: (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: [styles.adChipText, { color: palette.chipText }], children: "AD" }) }), (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: [styles.disclosure, { color: palette.disclosure }], numberOfLines: 1, children: "Indie pick" })] })] }), (0, jsx_runtime_1.jsx)(react_native_1.Animated.View, { style: [
                                styles.cta,
                                { backgroundColor: ctaBackground },
                                react_native_1.Platform.OS === 'ios' && {
                                    shadowColor: accent ? palette.ctaTinted : palette.cta,
                                    shadowOpacity: darkTheme ? 0.42 : 0.28,
                                    shadowRadius: 7,
                                    shadowOffset: { width: 0, height: 3 },
                                },
                            ], children: (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: [styles.ctaText, { color: palette.onCta }], children: card.cta }) })] }) }) }) }));
}
function CrossPromoImpressionView({ card, children, style, }) {
    const viewRef = (0, react_1.useRef)(null);
    const onQualified = (0, react_1.useCallback)((fraction, durationMs) => {
        void CrossPromo_1.CrossPromo.client.recordImpression(card, fraction, durationMs);
    }, [card]);
    useViewability(viewRef, card.impressionToken, onQualified);
    return ((0, jsx_runtime_1.jsx)(react_native_1.View, { ref: viewRef, collapsable: false, style: style, children: children }));
}
function useViewability(viewRef, impressionToken, onQualified) {
    (0, react_1.useEffect)(() => {
        let visibleSince;
        let highestFraction = 0;
        let reported = false;
        let active = react_native_1.AppState.currentState === 'active';
        const subscription = react_native_1.AppState.addEventListener('change', (state) => {
            active = state === 'active';
            if (!active)
                visibleSince = undefined;
        });
        const timer = setInterval(() => {
            if (!active || reported || !viewRef.current)
                return;
            viewRef.current.measureInWindow((x, y, width, height) => {
                if (width <= 0 || height <= 0) {
                    visibleSince = undefined;
                    return;
                }
                const screen = react_native_1.Dimensions.get('window');
                const intersectionWidth = Math.max(0, Math.min(x + width, screen.width) - Math.max(x, 0));
                const intersectionHeight = Math.max(0, Math.min(y + height, screen.height) - Math.max(y, 0));
                const fraction = (intersectionWidth * intersectionHeight) / (width * height);
                if (fraction < 0.5) {
                    visibleSince = undefined;
                    highestFraction = 0;
                    return;
                }
                highestFraction = Math.max(highestFraction, fraction);
                visibleSince ??= Date.now();
                const duration = Date.now() - visibleSince;
                if (duration >= 1_000) {
                    reported = true;
                    onQualified(highestFraction, duration);
                }
            });
        }, 100);
        return () => {
            clearInterval(timer);
            subscription.remove();
        };
    }, [impressionToken, onQualified, viewRef]);
}
const styles = react_native_1.StyleSheet.create({
    card: {
        minHeight: 84,
        padding: 14,
        borderRadius: 20,
        borderWidth: 1,
        flexDirection: 'row',
        alignItems: 'center',
    },
    cardLight: {
        shadowColor: '#000000',
        shadowOpacity: 0.07,
        shadowRadius: 14,
        shadowOffset: { width: 0, height: 6 },
        elevation: 2,
    },
    cardDark: {
        elevation: 0,
    },
    pressed: { opacity: 0.9 },
    iconHalo: {
        borderRadius: 14,
    },
    icon: {
        width: 56,
        height: 56,
        borderRadius: 14,
        borderWidth: react_native_1.StyleSheet.hairlineWidth,
        backgroundColor: 'rgba(127,127,127,0.12)',
    },
    iconLight: { borderColor: 'rgba(0,0,0,0.08)' },
    iconDark: { borderColor: 'rgba(255,255,255,0.16)' },
    copy: { flex: 1, marginHorizontal: 12 },
    appName: { fontSize: 16, fontWeight: '600' },
    tagline: { fontSize: 13, marginTop: 2 },
    disclosureRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginTop: 6,
    },
    adChip: {
        borderRadius: 5,
        paddingHorizontal: 5,
        paddingVertical: 2.5,
        marginRight: 6,
    },
    adChipText: {
        fontSize: 9,
        fontWeight: '800',
        letterSpacing: 0.8,
        lineHeight: 10,
    },
    disclosure: {
        fontSize: 11,
        fontWeight: '500',
        flexShrink: 1,
    },
    cta: {
        borderRadius: 100,
        paddingHorizontal: 16,
        paddingVertical: 8,
    },
    ctaText: { fontSize: 15, fontWeight: '600' },
});
