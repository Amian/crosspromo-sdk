"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CrossPromo = void 0;
const client_1 = require("./client");
const native_1 = require("./native");
class CrossPromo {
    /**
     * Everything an ad needs — the session handshake, one card, and its icon — is
     * fetched in the background as soon as this is called, so the first card the app
     * shows appears with no network wait.
     *
     * No placement is needed: a card is identical whichever slot it lands in, so the
     * one held here fills whichever placement appears first, and reports that slot
     * when it is actually seen. Pass `prefetch: false` to opt out.
     *
     * Best effort — it cannot throw into the caller, and anything that fails is
     * simply fetched on demand instead.
     */
    static configure(configuration) {
        const client = new client_1.CrossPromoClient(configuration, native_1.NativeCrossPromoPlatform, fetch);
        this.configuredClient = client;
        if (configuration.prefetch !== false)
            void client.prefetch();
    }
    static get client() {
        if (!this.configuredClient) {
            throw new Error('Call CrossPromo.configure before using the SDK.');
        }
        return this.configuredClient;
    }
}
exports.CrossPromo = CrossPromo;
