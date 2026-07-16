"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NativeCrossPromoPlatform = void 0;
const react_native_1 = require("react-native");
const LINKING_ERROR = `The CrossPromo native module is not linked on ${react_native_1.Platform.OS}. ` +
    'Run pod install on iOS and rebuild the app.';
exports.NativeCrossPromoPlatform = new Proxy({}, {
    get(_target, property) {
        const nativeModule = react_native_1.NativeModules.CrossPromoNative;
        if (!nativeModule) {
            return () => Promise.reject(new Error(LINKING_ERROR));
        }
        const value = nativeModule[property];
        return typeof value === 'function' ? value.bind(nativeModule) : value;
    },
});
