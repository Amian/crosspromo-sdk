# CrossPromo for Flutter

CrossPromo currently supports Flutter apps on iOS only.

Version `0.3.3` adds deterministic local card previews while retaining the
icon-derived colors and responsive sizing introduced in `0.3.2`.

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

The SDK automatically supplies the iOS bundle ID, version, and build number.

## Local mock previews

Use `PromoCardPreview` with a `PromoCardData` value and local `ImageProvider` to
exercise the production card presentation without backend requests, click handling,
or impression reporting. This is intended for sample apps, widget tests, and design
review; production integrations should continue to use `PromoCard`.

## App Store verification

The minimum supported version is iOS 16. CrossPromo does not require an App Attest
capability or an in-app purchase product. The native iOS portion of the plugin obtains
the Apple-signed App Transaction automatically.

For development, use the same dashboard key with
`CrossPromoEnvironment.sandbox`. Sandbox events never count. Production counting
requires a valid production App Transaction and a currently public App Store listing;
the API makes that decision, not the widget.

## Custom UI

Use `CrossPromo.client.fetchCard(placement: CrossPromoPlacement.postScan)`, wrap your UI
in `CrossPromoImpressionObserver(card: card, child: ...)`, and call
`CrossPromo.client.open(card)` on tap. The observer enforces the 50%-for-one-second SDK
threshold. The API additionally validates the single-use impression token and signed
click redirect.

## Privacy

The SDK does not store an installation ID, device ID, IP address, user agent, or locale.
The signed App Transaction is checked only to verify the registered public App Store app
and is then discarded. Follow the repository's short
[App Store Connect privacy guide](https://github.com/Amian/crosspromo-sdk/blob/main/APP_STORE_PRIVACY.md) before submitting.
