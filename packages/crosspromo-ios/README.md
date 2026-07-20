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

## Local mock previews

Use `CrossPromoCardPreview(card:icon:accentColor:)` in SwiftUI, or call
`displayPreview(card:icon:accentColor:)` on `CrossPromoCardUIView`, to exercise the
production card presentation with local data. Preview cards do not contact the backend,
open links, or report impressions. Production integrations should use `CrossPromoCard`.

## Test before release

Omit the environment argument. Debug builds automatically use sandbox and release builds
automatically use production:

```swift
try CrossPromo.configure(
    appKey: "cp_live_your_public_app_key"
)
```

Sandbox activity is visibly marked in the dashboard and never counts. Explicit
environment overrides remain available for unusual testing, but do not ship an explicit
sandbox override.
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

The SDK does not store an installation ID, device ID, IP address, user agent, or locale.
The signed App Transaction is checked only to verify the registered public App Store app
and is then discarded. Follow the repository's short
[App Store Connect privacy guide](https://github.com/Amian/crosspromo-sdk/blob/main/APP_STORE_PRIVACY.md) before submitting.
