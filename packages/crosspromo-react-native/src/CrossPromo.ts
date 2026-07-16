import { CrossPromoClient } from './client';
import { NativeCrossPromoPlatform } from './native';
import type { CrossPromoConfiguration } from './types';

export class CrossPromo {
  private static configuredClient?: CrossPromoClient;

  static configure(configuration: CrossPromoConfiguration): void {
    this.configuredClient = new CrossPromoClient(
      configuration,
      NativeCrossPromoPlatform,
      fetch,
    );
  }

  static get client(): CrossPromoClient {
    if (!this.configuredClient) {
      throw new Error('Call CrossPromo.configure before using the SDK.');
    }
    return this.configuredClient;
  }
}
