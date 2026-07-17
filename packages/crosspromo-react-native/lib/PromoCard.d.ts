import React from 'react';
import { type ImageSourcePropType, type StyleProp, type ViewStyle } from 'react-native';
import type { CrossPromoPlacement, IconAccentRgb, PromoCardData } from './types';
export interface PromoCardProps {
    placement: CrossPromoPlacement;
    style?: StyleProp<ViewStyle>;
    onError?: (error: unknown) => void;
    onLoaded?: (card: PromoCardData | null) => void;
}
export declare function PromoCard({ placement, style, onError, onLoaded, }: PromoCardProps): React.JSX.Element | null;
export interface PromoCardPreviewProps {
    card: PromoCardData;
    iconSource: ImageSourcePropType;
    accent?: IconAccentRgb;
    colorScheme?: 'light' | 'dark';
    style?: StyleProp<ViewStyle>;
    onPress?: () => void;
}
/** Renders the production card from local data without network or analytics. */
export declare function PromoCardPreview({ card, iconSource, accent, colorScheme, style, onPress, }: PromoCardPreviewProps): React.JSX.Element;
export interface CrossPromoImpressionViewProps {
    card: PromoCardData;
    children: React.ReactNode;
    style?: StyleProp<ViewStyle>;
}
export declare function CrossPromoImpressionView({ card, children, style, }: CrossPromoImpressionViewProps): React.JSX.Element;
