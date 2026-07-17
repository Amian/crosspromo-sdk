"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CrossPromoClient = exports.CrossPromoError = void 0;
const types_1 = require("./types");
class CrossPromoError extends Error {
    constructor(message, statusCode) {
        super(message);
        this.statusCode = statusCode;
        this.name = 'CrossPromoError';
    }
}
exports.CrossPromoError = CrossPromoError;
class CrossPromoClient {
    constructor(configuration, platform, fetcher) {
        this.platform = platform;
        this.fetcher = fetcher;
        if (!configuration.appKey.startsWith('cp_live_') &&
            !configuration.appKey.startsWith('cpn_live_')) {
            throw new CrossPromoError('appKey must be the key shown in your CrossPromo dashboard');
        }
        this.configuration = configuration;
        this.baseUrl = (configuration.baseUrl ??
            'https://backend-j5mh.onrender.com').replace(/\/$/, '');
        this.timeoutMs = configuration.requestTimeoutMs ?? 10_000;
        if (this.timeoutMs <= 0) {
            throw new CrossPromoError('requestTimeoutMs must be positive');
        }
    }
    async sessionStatus() {
        return (await this.validSession()).status;
    }
    async fetchCard(placement) {
        if (!Object.values(types_1.CrossPromoPlacement).includes(placement)) {
            throw new CrossPromoError('placement must be a CrossPromoPlacement option');
        }
        const session = await this.validSession();
        const response = await this.post('/v1/cards', { placement }, session.accessToken);
        return response.card ? cardFromWire(response.card) : null;
    }
    async recordImpression(card, visibleFraction, durationMs) {
        if (visibleFraction < 0.5 || durationMs < 1_000)
            return;
        const session = await this.validSession();
        await this.post('/v1/events/impressions', {
            impression_token: card.impressionToken,
            occurred_at: new Date().toISOString(),
            viewability: {
                visible_fraction: Math.max(0, Math.min(1, visibleFraction)),
                duration_ms: Math.floor(durationMs),
            },
        }, session.accessToken, randomId(), true);
    }
    async open(card) {
        await this.platform.openUrl(card.clickUrl);
    }
    async validSession() {
        if (this.session &&
            this.session.status.expiresAt.getTime() - Date.now() > 30_000) {
            return this.session;
        }
        if (this.sessionRequest)
            return this.sessionRequest;
        this.sessionRequest = this.createSession();
        try {
            this.session = await this.sessionRequest;
            return this.session;
        }
        finally {
            this.sessionRequest = undefined;
        }
    }
    async createSession() {
        const app = await this.platform.getAppContext();
        const challenge = await this.post('/v1/sdk/sessions/challenge', {
            app_key: this.configuration.appKey,
            environment: this.configuration.environment === 'sandbox' ? 'sandbox' : 'production',
            app: {
                platform: app.platform,
                bundle_id: app.bundle_id,
                version: app.version,
                build_number: app.build_number,
            },
            sdk: { name: 'crosspromo-react-native', version: '0.3.3' },
        });
        const evidence = await this.platform.generateEvidence({
            challenge_base64: challenge.challenge_base64,
            mode: challenge.integrity_mode,
            cloud_project_number: challenge.cloud_project_number,
        });
        const verified = await this.post('/v1/sdk/sessions/verify', {
            session_id: challenge.session_id,
            evidence,
        });
        return {
            accessToken: verified.access_token,
            status: {
                publisherAppId: verified.publisher_app_id,
                countsEnabled: verified.counts_enabled,
                reason: verified.reason,
                expiresAt: new Date(verified.expires_at),
            },
        };
    }
    async post(path, body, bearerToken, idempotencyKey, allowEmpty = false) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
        try {
            const response = await this.fetcher(`${this.baseUrl}${path}`, {
                method: 'POST',
                headers: {
                    Accept: 'application/json',
                    'Content-Type': 'application/json',
                    ...(bearerToken
                        ? { Authorization: `Bearer ${bearerToken}` }
                        : undefined),
                    ...(idempotencyKey
                        ? { 'Idempotency-Key': idempotencyKey }
                        : undefined),
                },
                body: JSON.stringify(body),
                signal: controller.signal,
            });
            const text = await response.text();
            if (!response.ok) {
                let message = 'Request failed';
                try {
                    const decoded = JSON.parse(text);
                    message = decoded.error?.message ?? message;
                }
                catch {
                    // A proxy may have returned a non-JSON error page.
                }
                throw new CrossPromoError(message, response.status);
            }
            if (!text && allowEmpty)
                return undefined;
            try {
                return JSON.parse(text);
            }
            catch {
                throw new CrossPromoError('The API returned invalid JSON');
            }
        }
        finally {
            clearTimeout(timeout);
        }
    }
}
exports.CrossPromoClient = CrossPromoClient;
function cardFromWire(card) {
    return {
        cardId: card.card_id,
        appName: card.app_name,
        iconUrl: card.icon_url,
        tagline: card.tagline,
        cta: card.cta,
        clickUrl: card.click_url,
        impressionToken: card.impression_token,
        expiresAt: new Date(card.expires_at),
    };
}
function randomId() {
    return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;
}
