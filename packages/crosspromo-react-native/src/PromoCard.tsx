import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  AppState,
  Dimensions,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { CrossPromo } from './CrossPromo';
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
  const onErrorRef = useRef(onError);
  const onLoadedRef = useRef(onLoaded);
  onErrorRef.current = onError;
  onLoadedRef.current = onLoaded;

  useEffect(() => {
    let active = true;
    setCard(null);
    CrossPromo.client
      .fetchCard(placement)
      .then((value) => {
        if (!active) return;
        setCard(value);
        onLoadedRef.current?.(value);
      })
      .catch((error: unknown) => {
        if (active) onErrorRef.current?.(error);
      });
    return () => {
      active = false;
    };
  }, [placement]);

  if (!card) return null;
  return (
    <CrossPromoImpressionView card={card} style={style}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Ad. ${card.appName}. ${card.tagline}`}
        onPress={() => void CrossPromo.client.open(card)}
        style={({ pressed }) => [styles.card, pressed && styles.pressed]}
      >
        <Image source={{ uri: card.iconUrl }} style={styles.icon} />
        <View style={styles.copy}>
          <Text style={styles.appName} numberOfLines={1}>
            {card.appName}
          </Text>
          <Text style={styles.tagline} numberOfLines={2}>
            {card.tagline}
          </Text>
          <Text style={styles.disclosure}>Ad · Indie pick</Text>
        </View>
        <View style={styles.button}>
          <Text style={styles.buttonText}>{card.cta}</Text>
        </View>
      </Pressable>
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
    minHeight: 82,
    padding: 12,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
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
