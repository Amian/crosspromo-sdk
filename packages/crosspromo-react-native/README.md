# CrossPromo for React Native

## Install

```sh
npm install git+https://github.com/Amian/crosspromo-sdk.git
cd ios && pod install
```

## Integrate

Configure once, before rendering your app:

```tsx
CrossPromo.configure({ appKey: 'cp_live_your_public_app_key' });
```

Drop in a card:

```tsx
<PromoCard placement="post_scan" />
```

The SDK automatically supplies the package/bundle ID, version, build number, locale,
and an app-scoped random installation ID.

## Store integrity setup

- **iOS:** add the App Attest capability and use the production App Attest environment
  for release builds. The minimum supported version is iOS 16.
- **Android:** enable Play Integrity for the app in Play Console and link the Google
  Cloud project selected in the CrossPromo dashboard.

For development, configure `{ environment: 'sandbox', appKey: 'cp_test_...' }`.
Sandbox events never enter the credit ledger. Production counting requires a production
Apple AppTransaction or Play Integrity `LICENSED` verdict and a currently public store
listing. The API, not JavaScript, makes that decision.

## Custom UI

Fetch with `CrossPromo.client.fetchCard(placement)`, wrap your design in
`<CrossPromoImpressionView card={card}>...</CrossPromoImpressionView>`, and call
`CrossPromo.client.open(card)` on press. Clicks are counted only by the signed redirect.

## Privacy

The SDK does not use IDFA, GAID, fingerprinting, or advertising identifiers. On iOS,
StoreKit's device-verification identifier is transmitted only with the signed
AppTransaction so the API can validate that it belongs to the current device; the API
contract forbids retaining the raw value.
