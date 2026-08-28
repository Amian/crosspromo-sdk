# CrossPromo for Apple platforms

Native Swift SDK for iOS 16+ and macOS 13+, distributed with Swift Package Manager.
It has no third-party runtime dependencies.

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

UIKit and AppKit integrations use the matching native view:

```swift
let iOSCard = CrossPromoCardUIView(placement: .settings)
let macCard = CrossPromoCardNSView(placement: .settings)
```

Those two concrete view types are platform-specific; `CrossPromoCard` has the same
SwiftUI initializer on iOS and macOS. Sandboxed Mac apps must enable the **Outgoing
Connections (Client)** capability in the host app target.

## Making cards appear instantly

`configure` fetches everything an ad needs — the session handshake, one card, and its
icon — in the background, so the first card the app shows appears with no network
wait. There is nothing to configure:

```swift
try CrossPromo.configure(appKey: "cp_live_your_public_app_key")
```

No placement is needed: a card is identical whichever slot it lands in, so the one
held for you fills whichever placement appears first and reports that slot when the
ad is actually seen. Prefetching is best effort and never throws — if it fails, the
card is fetched on demand exactly as before. Pass `prefetch: false` to opt out.

## Local mock previews

Use `CrossPromoCardPreview(card:icon:accentColor:)` in SwiftUI, or call
`displayPreview(card:icon:accentColor:)` on `CrossPromoCardUIView` or
`CrossPromoCardNSView`, to exercise the production card presentation with local data.
The preview accepts `UIImage`/`UIColor` on iOS and `NSImage`/`NSColor` on macOS. Preview
cards do not contact the backend, open links, or report impressions. Production
integrations should use `CrossPromoCard`.

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
Production counting is decided by the API, not by the app, and a sandbox session can
never count. Debug, local, TestFlight, and direct-distributed Mac builds do not establish
counting eligibility. A native Mac integration requires a public Mac App Store release
registered with the CrossPromo service. CrossPromo does not require an App Attest
capability or an in-app purchase product.

## Custom UI

`CrossPromoCard` is the supported integration and the one to use: it measures and
reports the ad on its own, so nothing else has to be wired up. If a design genuinely
cannot use it, fetch the data with
`try await CrossPromo.client.fetchCard(placement: .postScan)` and open `card.clickURL`
when the card is tapped. Reporting an ad the user did not actually see is a violation of
the network terms; the API decides what counts.

## Privacy

The SDK does not store an installation ID, device ID, IP address, user agent, or locale.
The signed App Transaction is checked only to verify the registered public App Store app
and is then discarded. Follow the repository's short
[App Store Connect privacy guide](https://github.com/Amian/crosspromo-sdk/blob/main/APP_STORE_PRIVACY.md) before submitting.
