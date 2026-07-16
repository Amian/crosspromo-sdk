"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CrossPromo = void 0;
const client_1 = require("./client");
const native_1 = require("./native");
class CrossPromo {
    static configure(configuration) {
        this.configuredClient = new client_1.CrossPromoClient(configuration, native_1.NativeCrossPromoPlatform, fetch);
    }
    static get client() {
        if (!this.configuredClient) {
            throw new Error('Call CrossPromo.configure before using the SDK.');
        }
        return this.configuredClient;
    }
}
exports.CrossPromo = CrossPromo;
