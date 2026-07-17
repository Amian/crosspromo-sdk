import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Animated,
  AppState,
  Dimensions,
  Easing,
  Image,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
  useColorScheme,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { accentFromRgb, buildPalette, type IconAccent } from './accent';
import { CrossPromo } from './CrossPromo';
import { NativeCrossPromoPlatform } from './native';
import type { CrossPromoPlacement, PromoCardData } from './types';

export interface PromoCardProps {
  placement: CrossPromoPlacement;
  style?: StyleProp<ViewStyle>;
  onError?: (error: unknown) => void;
  onLoaded?: (card: PromoCardData | null) => void;
}

export function PromoCard({
  placement,
  style,
  onError,
  onLoaded,
}: PromoCardProps): React.JSX.Element | null {
  const [card, setCard] = useState<PromoCardData | null>(null);
  const [accent, setAccent] = useState<IconAccent | null>(null);
  const scheme = useColorScheme();
  const darkTheme = scheme === 'dark';
  const entrance = useRef(new Animated.Value(0)).current;
  const tint = useRef(new Animated.Value(0)).current;
  const reduceMotionRef = useRef(false);
  const onErrorRef = useRef(onError);
  const onLoadedRef = useRef(onLoaded);
  onErrorRef.current = onError;
  onLoadedRef.current = onLoaded;

  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled()
      .then((enabled) => {
        if (active) reduceMotionRef.current = enabled;
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    let active = true;
    setCard(null);
    setAccent(null);
    entrance.setValue(0);
    tint.setValue(0);
    CrossPromo.client
      .fetchCard(placement)
      .then((value) => {
        if (!active) return;
        setCard(value);
        onLoadedRef.current?.(value);
        if (value) {
          if (reduceMotionRef.current) {
            entrance.setValue(1);
          } else {
            Animated.timing(entrance, {
              toValue: 1,
              duration: 420,
              easing: Easing.out(Easing.cubic),
              useNativeDriver: true,
            }).start();
          }
        }
      })
      .catch((error: unknown) => {
        if (active) onErrorRef.current?.(error);
      });
    return () => {
      active = false;
    };
  }, [placement, entrance, tint]);

  useEffect(() => {
    if (!card) return;
    const extract = NativeCrossPromoPlatform.extractIconAccent;
    if (typeof extract !== 'function') return;
    let active = true;
    extract(card.iconUrl)
      .then((rgb) => {
        if (!active || !rgb) return;
        setAccent(accentFromRgb(rgb));
        if (reduceMotionRef.current) {
          tint.setValue(1);
        } else {
          Animated.timing(tint, {
            toValue: 1,
            duration: 320,
            easing: Easing.out(Easing.quad),
            useNativeDriver: false,
          }).start();
        }
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, [card, tint]);

  if (!card) return null;
  const palette = buildPalette(accent, darkTheme);
  const crossFade = (from: string, to: string) =>
    tint.interpolate({ inputRange: [0, 1], outputRange: [from, to] });
  const surface = crossFade(palette.surface, palette.surfaceTinted);
  const border = crossFade(palette.border, palette.borderTinted);
  const ctaBackground = crossFade(palette.cta, palette.ctaTinted);
  const chipBackground = crossFade(
    palette.chipBackground,
    palette.chipBackgroundTinted,
  );

  return (
    <CrossPromoImpressionView card={card} style={style}>
      <Animated.View
        style={{
          opacity: entrance,
          transform: [
            {
              translateY: entrance.interpolate({
                inputRange: [0, 1],
                outputRange: [10, 0],
              }),
            },
          ],
        }}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Ad. ${card.appName}. ${card.tagline}`}
          onPress={() => void CrossPromo.client.open(card)}
          style={({ pressed }) => [
            pressed && styles.pressed,
            pressed && { transform: [{ scale: 0.98 }] },
          ]}
        >
          <Animated.View
            style={[
              styles.card,
              darkTheme ? styles.cardDark : styles.cardLight,
              { backgroundColor: surface, borderColor: border },
            ]}
          >
            <View style={styles.headerRow}>
              <View
                style={[
                  styles.iconHalo,
                  palette.glow !== null && {
                    shadowColor: palette.glow,
                    shadowOpacity: 1,
                    shadowRadius: 9,
                    shadowOffset: { width: 0, height: 3 },
                  },
                ]}
              >
                <Image
                  source={{ uri: card.iconUrl }}
                  style={[
                    styles.icon,
                    darkTheme ? styles.iconDark : styles.iconLight,
                  ]}
                />
              </View>
              <View style={styles.copy}>
                <Text
                  style={[styles.appName, { color: palette.appName }]}
                  numberOfLines={2}
                >
                  {card.appName}
                </Text>
                <Text
                  style={[styles.tagline, { color: palette.tagline }]}
                  numberOfLines={2}
                >
                  {card.tagline}
                </Text>
              </View>
              <Animated.View
                style={[styles.adChip, { backgroundColor: chipBackground }]}
              >
                <Text style={[styles.adChipText, { color: palette.chipText }]}>
                  AD
                </Text>
              </Animated.View>
            </View>
            <Animated.View
              style={[
                styles.cta,
                { backgroundColor: ctaBackground },
                Platform.OS === 'ios' && {
                  shadowColor: accent ? palette.ctaTinted : palette.cta,
                  shadowOpacity: darkTheme ? 0.42 : 0.28,
                  shadowRadius: 7,
                  shadowOffset: { width: 0, height: 3 },
                },
              ]}
            >
              <Text style={[styles.ctaText, { color: palette.onCta }]}>
                {card.cta}
              </Text>
            </Animated.View>
          </Animated.View>
        </Pressable>
      </Animated.View>
    </CrossPromoImpressionView>
  );
}

export interface CrossPromoImpressionViewProps {
  card: PromoCardData;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

export function CrossPromoImpressionView({
  card,
  children,
  style,
}: CrossPromoImpressionViewProps): React.JSX.Element {
  const viewRef = useRef<View>(null);
  const onQualified = useCallback(
    (fraction: number, durationMs: number) => {
      void CrossPromo.client.recordImpression(card, fraction, durationMs);
    },
    [card],
  );
  useViewability(viewRef, card.impressionToken, onQualified);
  return (
    <View ref={viewRef} collapsable={false} style={style}>
      {children}
    </View>
  );
}

function useViewability(
  viewRef: React.RefObject<View>,
  impressionToken: string,
  onQualified: (fraction: number, durationMs: number) => void,
): void {
  useEffect(() => {
    let visibleSince: number | undefined;
    let highestFraction = 0;
    let reported = false;
    let active = AppState.currentState === 'active';
    const subscription = AppState.addEventListener('change', (state) => {
      active = state === 'active';
      if (!active) visibleSince = undefined;
    });
    const timer = setInterval(() => {
      if (!active || reported || !viewRef.current) return;
      viewRef.current.measureInWindow((x, y, width, height) => {
        if (width <= 0 || height <= 0) {
          visibleSince = undefined;
          return;
        }
        const screen = Dimensions.get('window');
        const intersectionWidth = Math.max(
          0,
          Math.min(x + width, screen.width) - Math.max(x, 0),
        );
        const intersectionHeight = Math.max(
          0,
          Math.min(y + height, screen.height) - Math.max(y, 0),
        );
        const fraction =
          (intersectionWidth * intersectionHeight) / (width * height);
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

const styles = StyleSheet.create({
  card: {
    padding: 14,
    borderRadius: 20,
    borderWidth: 1,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 12,
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
    borderWidth: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(127,127,127,0.12)',
  },
  iconLight: { borderColor: 'rgba(0,0,0,0.08)' },
  iconDark: { borderColor: 'rgba(255,255,255,0.16)' },
  copy: { flex: 1, marginLeft: 12, marginRight: 8 },
  appName: { fontSize: 16, fontWeight: '600', lineHeight: 20 },
  tagline: { fontSize: 13, marginTop: 3 },
  adChip: {
    borderRadius: 5,
    paddingHorizontal: 5,
    paddingVertical: 2.5,
  },
  adChipText: {
    fontSize: 9,
    fontWeight: '800',
    letterSpacing: 0.8,
    lineHeight: 10,
  },
  cta: {
    borderRadius: 100,
    paddingHorizontal: 16,
    paddingVertical: 10,
    alignItems: 'center',
  },
  ctaText: { fontSize: 15, fontWeight: '600' },
});
