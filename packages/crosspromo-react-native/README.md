# CrossPromo for React Native

CrossPromo version 1 supports React Native apps on iOS only. Android support is
deferred to the [version 2 roadmap](../../V2_GOOGLE_PLAY.md).

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

The SDK automatically supplies the iOS bundle ID, version, build number, locale, and an
app-scoped random installation ID.

## App Store verification

The minimum supported version is iOS 16. CrossPromo does not require an App Attest
capability or an in-app purchase product. The native iOS portion of the module obtains
the Apple-signed App Transaction automatically.

For development, use the same dashboard key and configure
`{ environment: 'sandbox', appKey: 'cp_live_your_public_app_key' }`. Sandbox events
never count. Production counting requires a valid production App Transaction and a
currently public App Store listing. The API, not JavaScript, makes that decision.

## Custom UI

Fetch with `CrossPromo.client.fetchCard(CrossPromoPlacement.PostScan)`, wrap your design
in `<CrossPromoImpressionView card={card}>...</CrossPromoImpressionView>`, and call
`CrossPromo.client.open(card)` on press. Clicks are counted only by the signed redirect.

## Privacy

The signed App Transaction is used only to verify that SDK activity comes from the
registered public App Store app.
