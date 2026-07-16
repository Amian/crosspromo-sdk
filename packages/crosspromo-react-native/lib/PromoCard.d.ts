import React from 'react';
import { type StyleProp, type ViewStyle } from 'react-native';
import type { PromoCardData } from './types';
export interface PromoCardProps {
    placement: string;
    style?: StyleProp<ViewStyle>;
    onError?: (error: unknown) => void;
    onLoaded?: (card: PromoCardData | null) => void;
}
export declare function PromoCard({ placement, style, onError, onLoaded, }: PromoCardProps): React.JSX.Element | null;
export interface CrossPromoImpressionViewProps {
    card: PromoCardData;
    children: React.ReactNode;
    style?: StyleProp<ViewStyle>;
}
export declare function CrossPromoImpressionView({ card, children, style, }: CrossPromoImpressionViewProps): React.JSX.Element;
