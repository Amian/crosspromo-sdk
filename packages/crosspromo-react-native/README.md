# CrossPromo for React Native

CrossPromo currently supports React Native apps on iOS only.

## Install

```sh
npm install git+https://github.com/Amian/crosspromo-sdk.git
cd ios && pod install
```

## Integrate

Configure once, before rendering your app:

```tsx
import {
  CrossPromo,
  CrossPromoPlacement,
  PromoCard,
} from '@crosspromo/react-native';

CrossPromo.configure({ appKey: 'cp_live_your_public_app_key' });
```

Drop in a card:

```tsx
<PromoCard placement={CrossPromoPlacement.PostScan} />
```

Other typed options are `Result`, `Settings`, and `EmptyState`.

## Making cards appear instantly

`configure` fetches everything an ad needs — the session handshake, one card, and its
icon — in the background, so the first card the app shows appears with no network
wait. There is nothing to configure:

```tsx
CrossPromo.configure({ appKey: 'cp_live_your_public_app_key' });
```

No placement is needed: a card is identical whichever slot it lands in, so the one
held for you fills whichever placement appears first and reports that slot when the
ad is actually seen. Prefetching is best effort and never throws — if it fails, the
card is fetched on demand exactly as before. Pass `prefetch: false` to opt out.

## Local mock previews

Use `PromoCardPreview` with a `PromoCardData` object and local `iconSource` to exercise
the production card presentation without backend requests, click handling, or impression
reporting. This is intended for sample apps, component tests, and design review;
production integrations should continue to use `PromoCard`.

## App Store verification

The minimum supported version is iOS 16. CrossPromo does not require an App Attest
capability or an in-app purchase product. The native iOS portion of the module obtains
the Apple-signed App Transaction automatically.

When `environment` is omitted, development builds automatically use sandbox and release
builds automatically use production. Sandbox events never count. Production counting
requires a valid production App Transaction and a currently public App Store listing.
The API, not JavaScript, makes that decision. Explicit overrides remain available for
unusual testing, but do not ship an explicit sandbox override.

## Custom UI

`PromoCard` is the supported integration and the one to use. If a design genuinely
cannot use it, fetch with `CrossPromo.client.fetchCard(CrossPromoPlacement.PostScan)`,
wrap your design in `<CrossPromoImpressionView card={card}>...</CrossPromoImpressionView>`
so the ad is measured and reported for you, and call `CrossPromo.client.open(card)` on
press. Reporting an ad the user did not actually see is a violation of the network
terms; the API decides what counts.

## Privacy

The SDK does not store an installation ID, device ID, IP address, user agent, or locale.
The signed App Transaction is checked only to verify the registered public App Store app
and is then discarded. Follow the repository's short
[App Store Connect privacy guide](https://github.com/Amian/crosspromo-sdk/blob/main/APP_STORE_PRIVACY.md) before submitting.
