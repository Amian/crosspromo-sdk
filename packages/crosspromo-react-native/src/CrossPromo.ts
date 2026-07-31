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
   *
   * Otherwise, `configuration.warmUpSession` (default true) warms just the
   * session handshake, since that is two of the three requests an ad needs and
   * does not depend on knowing where ads will appear. Both are best effort and
   * neither can throw into the caller.
   */
  static configure(configuration: CrossPromoConfiguration): void {
    const client = new CrossPromoClient(
      configuration,
      NativeCrossPromoPlatform,
      fetch,
    );
    this.configuredClient = client;
    const placements = configuration.prefetchPlacements ?? [];
    if (placements.length > 0) {
      for (const placement of placements) {
        void client.prefetch(placement);
      }
    } else if (configuration.warmUpSession !== false) {
      // Prefetching already establishes the session, so only warm it separately
      // when there is nothing to prefetch.
      void client.warmUp();
    }
  }

  static get client(): CrossPromoClient {
    if (!this.configuredClient) {
      throw new Error('Call CrossPromo.configure before using the SDK.');
    }
    return this.configuredClient;
  }
}
