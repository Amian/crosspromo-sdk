import { CrossPromoClient } from './client';
import type { CrossPromoConfiguration } from './types';
export declare class CrossPromo {
    private static configuredClient?;
    static configure(configuration: CrossPromoConfiguration): void;
    static get client(): CrossPromoClient;
}
