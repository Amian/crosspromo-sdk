# CrossPromo SDK

Add a small “you might also like” app recommendation card to your mobile app.

## The whole setup

1. [Add your App Store app to the CrossPromo dashboard](https://crosspromo-developer-dashboard.pages.dev/auth).
2. Copy the ready-made prompt from your dashboard into your coding agent.
3. Submit the updated app to Apple. CrossPromo automatically recognizes verified
   activity after that version is public.

CrossPromo supports:

- native iPhone/iPad apps using Swift or SwiftUI;
- Flutter apps running on iOS; and
- React Native apps running on iOS.

> **CrossPromo currently supports iOS only.** The SDK and backend can be used for
> integration testing. Only verified activity from a public App Store release counts.

## Fastest option: ask your coding agent

Copy the prompt below into Codex, Claude Code, Cursor, Copilot, or another coding AI
while it has your app project open.

```text
Integrate the CrossPromo mobile SDK into this app.

SDK repository: https://github.com/Amian/crosspromo-sdk

Please work autonomously and make the integration changes for me:

1. Confirm this is a native iOS, Flutter iOS, or React Native iOS app. CrossPromo v1
   does not support Android.
2. Read the CrossPromo root README and the README for the matching package.
3. Install the SDK directly from the GitHub repository using the documented method.
4. Configure CrossPromo once at app startup. Ask me to copy my app key from the
   CrossPromo dashboard if it is not already present. Omit the environment argument:
   the SDK automatically uses sandbox in debug builds and production in release builds.
   Do not hard-code sandbox in code that will ship.
5. Add one PromoCard to an existing, sensible screen—prefer a success/result screen,
   then settings or an empty state. Do not redesign the rest of the screen.
6. Use the SDK's typed placement option that best fits the screen: post-scan, result,
   settings, or empty state. Do not pass a raw string.
7. Confirm the iOS deployment target is iOS 16 or later. CrossPromo does not require
   an App Attest capability or an in-app purchase product.
8. Run the relevant formatter, tests, and an iOS build. Fix integration errors.
9. Finish by listing the files you changed and remind me to complete the CrossPromo
   choices in APP_STORE_PRIVACY.md before submitting the app update.
```

The developer only needs to provide the app key shown in the CrossPromo dashboard.

## Manual integration

### Native iOS

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/Amian/crosspromo-sdk
```

Configure once when the app starts:

```swift
import CrossPromo

try CrossPromo.configure(
    appKey: "cp_live_YOUR_KEY_FROM_DASHBOARD"
)
```

Add the card to a SwiftUI screen:

```swift
CrossPromoCard(placement: .postScan)
```

UIKit apps can use `CrossPromoCardUIView(placement: .postScan)`.

[Detailed iOS instructions](packages/crosspromo-ios/README.md)

### Flutter on iOS

Add this to `pubspec.yaml`:

```yaml
dependencies:
  crosspromo_sdk:
    git:
      url: https://github.com/Amian/crosspromo-sdk.git
      path: packages/crosspromo-flutter
```

Configure before `runApp`:

```dart
CrossPromo.configure(
  appKey: 'cp_live_YOUR_KEY_FROM_DASHBOARD',
);
```

Add the card:

```dart
const PromoCard(placement: CrossPromoPlacement.postScan)
```

[Detailed Flutter instructions](packages/crosspromo-flutter/README.md)

### React Native on iOS

Install directly from GitHub:

```sh
npm install git+https://github.com/Amian/crosspromo-sdk.git
cd ios && pod install
```

Configure before rendering the app:

```tsx
import {
  CrossPromo,
  CrossPromoPlacement,
  PromoCard,
} from '@crosspromo/react-native';

CrossPromo.configure({
  appKey: 'cp_live_YOUR_KEY_FROM_DASHBOARD',
});
```

Add the card:

```tsx
<PromoCard placement={CrossPromoPlacement.PostScan} />
```

Placements are typed options, so a misspelling is caught before the app runs.

[Detailed React Native instructions](packages/crosspromo-react-native/README.md)

## Release setup

No manual environment switch is required. When the environment argument is omitted,
the SDK uses sandbox in debug builds and production in release builds. Before release:

- the app must target iOS 16 or later;
- the SDK must be included in a version released through the public App Store; and
- the dashboard registration must match the app's bundle ID and numeric Apple app ID.

Keep the environment argument omitted for the App Store build. Explicit overrides remain
available for unusual testing, but do not ship an explicit sandbox override.

CrossPromo does not require an App Attest capability or an in-app purchase product.
The SDK reads the app identifier, version, build number, and Apple-signed App
Transaction automatically.

## App Store privacy — five small choices

Before submitting the version that contains CrossPromo, open **App Store Connect →
your app → App Privacy**. Keep your app's existing answers, then add:

- **Usage Data → Product Interaction**
- **Usage Data → Advertising Data**

For both, select **Third-Party Advertising** and **Analytics**, then answer **No** to
**Linked to the user** and **No** to **Used for tracking**. CrossPromo does not require
**Device ID** or an ATT prompt.

[See the exact click-by-click privacy guide](APP_STORE_PRIVACY.md).

## How counting is protected

The app cannot decide whether an impression or click counts.

- iOS sessions provide an Apple-signed App Transaction.
- The backend verifies its signature, production environment, bundle ID, Apple app ID,
  and released version.
- The backend also confirms that the app is currently public in the App Store.
- Impressions use single-use server tokens and require 50% visibility for one second.
- Clicks count only through a signed server redirect. There is no client-side
  `recordClick()` function.

Debug builds, StoreKit testing, simulators, TestFlight, and sandbox activity never earn
eligibility or counted activity. Google Play support is deliberately outside the v1
production scope.

CrossPromo stores events against participating apps, not people or devices. It does not
store an installation ID, App Transaction ID, IP address, user agent, or locale. The
Apple-signed App Transaction is checked during verification and then discarded.

## Repository layout

| Package | Location |
|---|---|
| Native iOS | [`packages/crosspromo-ios`](packages/crosspromo-ios) |
| Flutter | [`packages/crosspromo-flutter`](packages/crosspromo-flutter) |
| React Native | [`packages/crosspromo-react-native`](packages/crosspromo-react-native) |

## Development checks

```sh
cd packages/crosspromo-ios && swift test
cd packages/crosspromo-flutter && flutter analyze && flutter test
cd packages/crosspromo-react-native && npm install && npm run typecheck && npm test
```

Licensed under the [MIT License](LICENSE).
