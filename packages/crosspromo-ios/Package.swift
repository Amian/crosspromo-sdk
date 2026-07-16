// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CrossPromo",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "CrossPromo", targets: ["CrossPromo"]),
    ],
    targets: [
        .target(name: "CrossPromo"),
        .testTarget(name: "CrossPromoTests", dependencies: ["CrossPromo"]),
    ]
)
