// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnyFontUse",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "AnyFontUse",
            targets: ["AnyFontUse"]
        ),
    ],
    targets: [
        .target(
            name: "AnyFontUse"
        ),
    ],
    swiftLanguageModes: [.v6]
)
