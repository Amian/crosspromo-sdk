// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CrossPromo",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "CrossPromo", targets: ["CrossPromo"]),
    ],
    targets: [
        .target(
            name: "CrossPromo",
            resources: [.copy("PrivacyInfo.xcprivacy"), .process("Resources")]
        ),
        .testTarget(name: "CrossPromoTests", dependencies: ["CrossPromo"]),
    ]
)
