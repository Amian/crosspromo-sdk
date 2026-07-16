# CrossPromo for iOS

Native Swift SDK for iOS 16+, distributed with Swift Package Manager. It has no
third-party runtime dependencies.

## Install

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/Amian/crosspromo-sdk`, then select the `CrossPromo` library for your
app target.

## Integrate

Configure once in your app entry point:

```swift
import CrossPromo

@main
struct ExampleApp: App {
    init() {
        try! CrossPromo.configure(appKey: "cp_live_your_public_app_key")
    }

    var body: some Scene { WindowGroup { ContentView() } }
}
```

Drop the SwiftUI card where a recommendation fits naturally:

```swift
CrossPromoCard(placement: .postScan)
```

UIKit apps can use `CrossPromoCardUIView(placement: .postScan)` directly. Available
options are `.postScan`, `.result`, `.settings`, and `.emptyState`. No app
version or bundle identifier configuration is needed; the SDK reads both from the app.

## Test before release

Use the sandbox endpoint and a test key:

```swift
try CrossPromo.configure(appKey: "cp_test_...", environment: .sandbox)
```

Sandbox activity is visibly marked in the dashboard and never enters the credit ledger.
Production counting is decided by the API after validating App Attest, Apple-signed
AppTransaction evidence, the registered bundle/team identity, and the live App Store
listing. A missing or sandbox AppTransaction cannot earn credits.

## Custom UI

Fetch data with `try await CrossPromo.client.fetchCard(placement: .postScan)`. If you
render it yourself, call `recordImpression(for:visibleFraction:duration:)` only after at
least 50% has been continuously visible for one second. The server still validates the
single-use impression token. Open `card.clickURL` when the card is tapped.

## Privacy

The SDK creates a random, app-scoped installation ID. It does not access IDFA, track a
person across apps, fingerprint devices, or perform install attribution. StoreKit's
device-verification identifier is transmitted only with the signed AppTransaction so
the API can validate that it belongs to the current device; the API contract forbids
retaining the raw value.
