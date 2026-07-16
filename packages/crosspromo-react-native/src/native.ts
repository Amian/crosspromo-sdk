import { NativeModules, Platform } from 'react-native';

import type { CrossPromoPlatform } from './types';

const LINKING_ERROR =
  `The CrossPromo native module is not linked on ${Platform.OS}. ` +
  'Run pod install on iOS and rebuild the app.';

export const NativeCrossPromoPlatform: CrossPromoPlatform = new Proxy(
  {} as CrossPromoPlatform,
  {
    get(_target, property) {
      const nativeModule = NativeModules.CrossPromoNative as
        | CrossPromoPlatform
        | undefined;
      if (!nativeModule) {
        return () => Promise.reject(new Error(LINKING_ERROR));
      }
      const value = nativeModule[property as keyof CrossPromoPlatform];
      return typeof value === 'function' ? value.bind(nativeModule) : value;
    },
  },
);
