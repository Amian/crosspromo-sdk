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

Use your dashboard app key with the sandbox environment:

```swift
try CrossPromo.configure(
    appKey: "cp_live_your_public_app_key",
    environment: .sandbox
)
```

Sandbox activity is visibly marked in the dashboard and never counts.
Production counting is decided by the API after validating the Apple-signed App
Transaction, the registered app identity and version, and the live App Store listing.
A missing or sandbox App Transaction cannot count. CrossPromo does not require
an App Attest capability or an in-app purchase product.

## Custom UI

Fetch data with `try await CrossPromo.client.fetchCard(placement: .postScan)`. If you
render it yourself, call `recordImpression(for:visibleFraction:duration:)` only after at
least 50% has been continuously visible for one second. The server still validates the
single-use impression token. Open `card.clickURL` when the card is tapped.

## Privacy

The SDK creates a random, app-scoped installation ID. It does not access IDFA, track a
person across apps, fingerprint devices, or perform install attribution. The signed App
Transaction is used only to verify that SDK activity comes from the registered public
App Store app.
