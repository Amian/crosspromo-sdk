"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CrossPromoClient = exports.CrossPromoError = exports.resolveEnvironment = void 0;
const iconWarmer_1 = require("./iconWarmer");
const types_1 = require("./types");
const resolveEnvironment = (environment, isDevelopment = typeof __DEV__ !== 'undefined' && __DEV__) => environment ?? (isDevelopment ? 'sandbox' : 'production');
exports.resolveEnvironment = resolveEnvironment;
class CrossPromoError extends Error {
    constructor(message, statusCode) {
        super(message);
        this.statusCode = statusCode;
        this.name = 'CrossPromoError';
    }
}
exports.CrossPromoError = CrossPromoError;
class CrossPromoClient {
    constructor(configuration, platform, fetcher, iconWarmer = iconWarmer_1.warmCrossPromoIcon) {
        this.platform = platform;
        this.fetcher = fetcher;
        this.iconWarmer = iconWarmer;
        /**
         * Cards fetched ahead of being needed, keyed by placement.
         *
         * Cards are single use: each carries its own impression token, and the backend
         * treats a repeated token as a replay. Handing one card to two placements would
         * therefore silently drop the second impression, so taking a prefetched card
         * removes it from here.
         */
        this.prefetched = new Map();
        this.prefetchRequests = new Map();
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
    /**
     * Does the slow part of showing an ad before there is anywhere to show it: the
     * session handshake and one card fetch. Call it at app start, or as soon as you
     * know a placement is coming, and the matching {@link fetchCard} returns
     * immediately.
     *
     * Best effort by design — failures are swallowed, because a prefetch that did
     * not work must not surface as an error at a point where the app was not even
     * showing an ad. The card is simply fetched on demand instead.
     *
     * Safe to call repeatedly: concurrent calls for one placement share a single
     * fetch, and a placement that already holds a fresh card does nothing.
     */
    prefetch(placement) {
        const key = placement;
        const inflight = this.prefetchRequests.get(key);
        if (inflight)
            return inflight;
        if (this.prefetched.has(key))
            return Promise.resolve();
        const request = this.runPrefetch(key, placement);
        this.prefetchRequests.set(key, request);
        return request;
    }
    /**
     * Warms only the session handshake, for apps that want the credential ready
     * without holding a card that could go stale.
     */
    async warmUp() {
        try {
            await this.validSession();
        }
        catch {
            // Best effort, exactly like prefetch.
        }
    }
    async runPrefetch(key, placement) {
        try {
            const card = await this.requestCard(placement);
            if (card) {
                this.prefetched.set(key, card);
                // Pull the icon in too. Without this the card text would appear instantly
                // and the icon would still fade in a beat later.
                this.iconWarmer(card.iconUrl);
            }
        }
        catch {
            // Swallowed: see prefetch's contract.
        }
        finally {
            this.prefetchRequests.delete(key);
        }
    }
    async fetchCard(placement) {
        if (!Object.values(types_1.CrossPromoPlacement).includes(placement)) {
            throw new CrossPromoError('placement must be a CrossPromoPlacement option');
        }
        const key = placement;
        const ready = this.takePrefetched(key);
        if (ready)
            return ready;
        // A prefetch already on the wire: wait for it rather than starting a second
        // identical request and wasting the impression the first one is holding.
        const inflight = this.prefetchRequests.get(key);
        if (inflight) {
            await inflight;
            const arrived = this.takePrefetched(key);
            if (arrived)
                return arrived;
        }
        return this.requestCard(placement);
    }
    takePrefetched(key) {
        const held = this.prefetched.get(key);
        if (!held)
            return null;
        this.prefetched.delete(key);
        const remaining = held.expiresAt.getTime() - Date.now();
        return remaining > CrossPromoClient.cardMinimumRemainingMs ? held : null;
    }
    async requestCard(placement) {
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
        if (this.session) {
            const remaining = this.session.status.expiresAt.getTime() - Date.now();
            if (remaining > CrossPromoClient.sessionMinimumRemainingMs) {
                if (remaining < CrossPromoClient.sessionRefreshMarginMs) {
                    // Still usable, but close enough to expiry that the next ad would have
                    // paid for a fresh handshake. Renew behind this request and answer it
                    // with the token we already hold.
                    this.renewSessionInBackground();
                }
                return this.session;
            }
        }
        return this.startSession();
    }
    async startSession() {
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
    renewSessionInBackground() {
        if (this.sessionRequest)
            return;
        void this.startSession().catch(() => { });
    }
    async createSession() {
        const app = await this.platform.getAppContext();
        const challenge = await this.post('/v1/sdk/sessions/challenge', {
            app_key: this.configuration.appKey,
            environment: (0, exports.resolveEnvironment)(this.configuration.environment),
            app: {
                platform: app.platform,
                bundle_id: app.bundle_id,
                version: app.version,
                build_number: app.build_number,
            },
            sdk: { name: 'crosspromo-react-native', version: '0.3.5' },
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
/**
 * A session this close to expiring is renewed before it is handed out, so a
 * request can never be signed with a token that dies mid-flight.
 */
CrossPromoClient.sessionMinimumRemainingMs = 30_000;
/**
 * A still-valid session with less than this left is renewed in the background,
 * so an ad request practically never waits for the three-call handshake.
 */
CrossPromoClient.sessionRefreshMarginMs = 120_000;
/**
 * A prefetched card has to outlive the viewability window it is about to be
 * measured against, so one that is nearly expired is discarded rather than
 * shown and then failing to record.
 */
CrossPromoClient.cardMinimumRemainingMs = 30_000;
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
