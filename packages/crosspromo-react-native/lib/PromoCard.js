"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PromoCard = PromoCard;
exports.CrossPromoImpressionView = CrossPromoImpressionView;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const react_native_1 = require("react-native");
const CrossPromo_1 = require("./CrossPromo");
function PromoCard({ placement, style, onError, onLoaded, }) {
    const [card, setCard] = (0, react_1.useState)(null);
    const onErrorRef = (0, react_1.useRef)(onError);
    const onLoadedRef = (0, react_1.useRef)(onLoaded);
    onErrorRef.current = onError;
    onLoadedRef.current = onLoaded;
    (0, react_1.useEffect)(() => {
        let active = true;
        setCard(null);
        CrossPromo_1.CrossPromo.client
            .fetchCard(placement)
            .then((value) => {
            if (!active)
                return;
            setCard(value);
            onLoadedRef.current?.(value);
        })
            .catch((error) => {
            if (active)
                onErrorRef.current?.(error);
        });
        return () => {
            active = false;
        };
    }, [placement]);
    if (!card)
        return null;
    return ((0, jsx_runtime_1.jsx)(CrossPromoImpressionView, { card: card, style: style, children: (0, jsx_runtime_1.jsxs)(react_native_1.Pressable, { accessibilityRole: "button", accessibilityLabel: `Ad. ${card.appName}. ${card.tagline}`, onPress: () => void CrossPromo_1.CrossPromo.client.open(card), style: ({ pressed }) => [styles.card, pressed && styles.pressed], children: [(0, jsx_runtime_1.jsx)(react_native_1.Image, { source: { uri: card.iconUrl }, style: styles.icon }), (0, jsx_runtime_1.jsxs)(react_native_1.View, { style: styles.copy, children: [(0, jsx_runtime_1.jsx)(react_native_1.Text, { style: styles.appName, numberOfLines: 1, children: card.appName }), (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: styles.tagline, numberOfLines: 2, children: card.tagline }), (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: styles.disclosure, children: "Ad \u00B7 Indie pick" })] }), (0, jsx_runtime_1.jsx)(react_native_1.View, { style: styles.button, children: (0, jsx_runtime_1.jsx)(react_native_1.Text, { style: styles.buttonText, children: card.cta }) })] }) }));
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
        minHeight: 82,
        padding: 12,
        borderRadius: 12,
        borderWidth: react_native_1.StyleSheet.hairlineWidth,
        borderColor: '#8E8E93',
        backgroundColor: '#F2F2F7',
        flexDirection: 'row',
        alignItems: 'center',
    },
    pressed: { opacity: 0.78 },
    icon: { width: 58, height: 58, borderRadius: 12, backgroundColor: '#E5E5EA' },
    copy: { flex: 1, marginHorizontal: 12 },
    appName: { color: '#111111', fontSize: 16, fontWeight: '600' },
    tagline: { color: '#55555A', fontSize: 13, marginTop: 2 },
    disclosure: { color: '#8E8E93', fontSize: 10, marginTop: 3 },
    button: {
        borderRadius: 16,
        paddingHorizontal: 14,
        paddingVertical: 7,
        backgroundColor: '#0A84FF',
    },
    buttonText: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
});
