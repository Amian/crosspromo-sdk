import { CrossPromoClient } from './client';
import { NativeCrossPromoPlatform } from './native';
import type { CrossPromoConfiguration } from './types';

export class CrossPromo {
  private static configuredClient?: CrossPromoClient;

  /**
   * `configuration.prefetchPlacements` warms the session and one card for each
   * placement given, in the background, so the first card the app shows appears
   * without a network wait. Pass the placements the app actually uses — a
   * prefetched card is held until something asks for it, and anything that
   * fails is fetched on demand.
   */
  static configure(configuration: CrossPromoConfiguration): void {
    const client = new CrossPromoClient(
      configuration,
      NativeCrossPromoPlatform,
      fetch,
    );
    this.configuredClient = client;
    for (const placement of configuration.prefetchPlacements ?? []) {
      void client.prefetch(placement);
    }
  }

  static get client(): CrossPromoClient {
    if (!this.configuredClient) {
      throw new Error('Call CrossPromo.configure before using the SDK.');
    }
    return this.configuredClient;
  }
}
