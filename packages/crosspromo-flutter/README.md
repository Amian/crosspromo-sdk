# CrossPromo for Flutter

CrossPromo currently supports Flutter apps on iOS only.

Version `0.3.4` automatically uses sandbox for debug builds and production for release
builds while retaining the icon-derived colors and responsive sizing introduced in
`0.3.2`.

## Install

Add the package to `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  crosspromo_sdk:
    git:
      url: https://github.com/Amian/crosspromo-sdk.git
      path: packages/crosspromo-flutter
```

## Integrate

Configure once before `runApp`:

```dart
void main() {
  CrossPromo.configure(appKey: 'cp_live_your_public_app_key');
  runApp(const MyApp());
}
```

Drop in a card:

```dart
const PromoCard(placement: CrossPromoPlacement.postScan)
```

Other typed options are `.result`, `.settings`, and `.emptyState`.

## Making cards appear instantly

`configure` fetches everything an ad needs — the session handshake, one card, and its
icon — in the background, so the first card the app shows appears with no network
wait. There is nothing to configure:

```dart
CrossPromo.configure(appKey: 'cp_live_your_public_app_key');
```

No placement is needed: a card is identical whichever slot it lands in, so the one
held for you fills whichever placement appears first and reports that slot when the
ad is actually seen. Prefetching is best effort and never throws — if it fails, the
card is fetched on demand exactly as before. Pass `prefetch: false` to opt out.

## Local mock previews

Use `PromoCardPreview` with a `PromoCardData` value and local `ImageProvider` to
exercise the production card presentation without backend requests, click handling,
or impression reporting. This is intended for sample apps, widget tests, and design
review; production integrations should continue to use `PromoCard`.

## App Store verification

The minimum supported version is iOS 16. CrossPromo does not require an App Attest
capability or an in-app purchase product. The native iOS portion of the plugin obtains
the Apple-signed App Transaction automatically.

When the environment argument is omitted, debug builds automatically use sandbox and
release builds automatically use production. Sandbox events never count. Production
counting requires a valid production App Transaction and a currently public App Store
listing; the API makes that decision, not the widget. Explicit overrides remain
available for unusual testing, but do not ship an explicit sandbox override.

## Custom UI

`PromoCard` is the supported integration and the one to use. If a design genuinely
cannot use it, fetch with
`CrossPromo.client.fetchCard(placement: CrossPromoPlacement.postScan)`, wrap your UI in
`CrossPromoImpressionObserver(card: card, child: ...)` so the ad is measured and
reported for you, and call `CrossPromo.client.open(card)` on tap. Reporting an ad the
user did not actually see is a violation of the network terms; the API decides what
counts.

## Privacy

The SDK does not store an installation ID, device ID, IP address, user agent, or locale.
The signed App Transaction is checked only to verify the registered public App Store app
and is then discarded. Follow the repository's short
[App Store Connect privacy guide](https://github.com/Amian/crosspromo-sdk/blob/main/APP_STORE_PRIVACY.md) before submitting.
