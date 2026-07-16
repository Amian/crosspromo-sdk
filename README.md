# CrossPromo SDK

Add a small “you might also like” app recommendation card to your mobile app.

CrossPromo supports:

- native iPhone/iPad apps using Swift or SwiftUI;
- Flutter apps on iOS and Android; and
- React Native apps on iOS and Android.

> **Current status:** The SDK is ready to integrate and test-build. The production
> CrossPromo service and app keys are not live yet because the backend is the next
> project phase. No backend is included in this repository.

## Fastest option: ask your coding agent

Copy the prompt below into Codex, Claude Code, Cursor, Copilot, or another coding AI
while it has your app project open.

```text
Integrate the CrossPromo mobile SDK into this app.

SDK repository: https://github.com/Amian/crosspromo-sdk

Please work autonomously and make the integration changes for me:

1. Detect whether this is native iOS, Flutter, or React Native.
2. Read the CrossPromo root README and the README for the matching package.
3. Install the SDK directly from the GitHub repository using the documented method.
4. Configure CrossPromo once at app startup. If I have not provided a real app key,
   use `cp_test_REPLACE_ME` as an obvious placeholder and tell me exactly where to
   replace it later. Do not invent a production key.
5. Add one PromoCard to an existing, sensible screen—prefer a success/result screen,
   then settings or an empty state. Do not redesign the rest of the screen.
6. Use the SDK's typed placement option that best fits the screen: post-scan, result,
   settings, or empty state. Do not pass a raw string.
7. Apply the required native setup: iOS 16+ and App Attest on iOS; Android 23+ and
   Play Integrity on Android.
8. Run the relevant formatter, tests, and a platform build. Fix integration errors.
9. Finish by listing the files you changed and the one remaining action I need to take.
```

That should leave only one manual step later: replacing the test placeholder with the
app key issued by the CrossPromo dashboard.

## Manual integration

### Native iOS

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/Amian/crosspromo-sdk
```

Configure once when the app starts:

```swift
import CrossPromo

try CrossPromo.configure(appKey: "cp_test_REPLACE_ME", environment: .sandbox)
```

Add the card to a SwiftUI screen:

```swift
CrossPromoCard(placement: .postScan)
```

UIKit apps can use `CrossPromoCardUIView(placement: .postScan)`.

[Detailed iOS instructions](packages/crosspromo-ios/README.md)

### Flutter

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
  appKey: 'cp_test_REPLACE_ME',
  environment: CrossPromoEnvironment.sandbox,
);
```

Add the card:

```dart
const PromoCard(placement: CrossPromoPlacement.postScan)
```

[Detailed Flutter instructions](packages/crosspromo-flutter/README.md)

### React Native

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
  appKey: 'cp_test_REPLACE_ME',
  environment: 'sandbox',
});
```

Add the card:

```tsx
<PromoCard placement={CrossPromoPlacement.PostScan} />
```

Placements are typed options, so a misspelling is caught before the app runs.

[Detailed React Native instructions](packages/crosspromo-react-native/README.md)

## Release setup

Before using a live key:

- iOS apps must target iOS 16 or later and enable the **App Attest** capability.
- Android apps must target Android API 23 or later and enable **Play Integrity** in
  Play Console.

The SDK automatically reads the app identifier, version, and build number. It does not
use IDFA, GAID, fingerprinting, or install attribution.

## How counting is protected

The app cannot decide whether an impression or click counts.

- iOS sessions use App Attest and an Apple-signed AppTransaction tied to the device.
- Android sessions use Play Integrity and require a Play-recognized, licensed app.
- The future backend must independently confirm the app is currently public in the App
  Store or Google Play.
- Impressions use single-use server tokens and require 50% visibility for one second.
- Clicks count only through a signed server redirect. There is no client-side
  `recordClick()` function.

For the complete server contract and fraud controls, see the
[backend API plan](docs/backend-api-plan.md).

## Repository layout

| Package | Location |
|---|---|
| Native iOS | [`packages/crosspromo-ios`](packages/crosspromo-ios) |
| Flutter | [`packages/crosspromo-flutter`](packages/crosspromo-flutter) |
| React Native | [`packages/crosspromo-react-native`](packages/crosspromo-react-native) |
| Backend plan | [`docs/backend-api-plan.md`](docs/backend-api-plan.md) |

## Development checks

```sh
cd packages/crosspromo-ios && swift test
cd packages/crosspromo-flutter && flutter analyze && flutter test
cd packages/crosspromo-react-native && npm install && npm run typecheck && npm test
```

Licensed under the [MIT License](LICENSE).
