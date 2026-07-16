# CrossPromo for Flutter

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
const PromoCard(placement: 'post_scan')
```

The SDK automatically supplies the package/bundle ID, version, build number, locale,
and an app-scoped random installation ID.

## Store integrity setup

- **iOS:** add the App Attest capability and set `App Attest Environment` to
  `production` for release builds. The minimum supported version is iOS 16.
- **Android:** enable Play Integrity for the app in Play Console and link the Google
  Cloud project selected in the CrossPromo dashboard. The plugin uses the official Play
  Integrity library; no project number is embedded in your Dart code.

For development, use `CrossPromoEnvironment.sandbox` with a `cp_test_...` key. Sandbox
events never enter the credit ledger. Production counting requires a production Apple
AppTransaction or Play Integrity `LICENSED` verdict and a currently public store
listing; the API makes that decision, not the widget.

## Custom UI

Use `CrossPromo.client.fetchCard(placement:)`, wrap your UI in
`CrossPromoImpressionObserver(card: card, child: ...)`, and call
`CrossPromo.client.open(card)` on tap. The observer enforces the 50%-for-one-second SDK
threshold. The API additionally validates the single-use impression token and signed
click redirect.

## Privacy

The SDK does not use IDFA, GAID, fingerprinting, or advertising identifiers. On iOS,
StoreKit's device-verification identifier is transmitted only with the signed
AppTransaction so the API can validate that it belongs to the current device; the API
contract forbids retaining the raw value.
