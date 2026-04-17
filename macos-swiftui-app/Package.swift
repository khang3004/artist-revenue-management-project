// swift-tools-version: 5.10
// Amplify Core — macOS Artist Revenue Management Application
// Toolchain: Xcode 16+ / Swift 5.10+
// Deployment target: macOS 26.0 (Tahoe) — Required for Liquid Glass APIs:
//   .glassEffect(_:in:), GlassEffectContainer, .buttonStyle(.glass),
//   .backgroundExtensionEffect(), ConcentricRectangle

import PackageDescription

let package = Package(
    name: "AmplifyCore",
    defaultLocalization: "en",
    platforms: [
        .macOS("26.0")   // Tahoe: Liquid Glass, glassEffect, GlassEffectContainer
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-log.git",    from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ArtistRevenueMacApp",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging",     package: "swift-log"),
            ],
            path: "Sources/ArtistRevenueMacApp"
        ),
        .testTarget(
            name: "AmplifyCoreTests",
            dependencies: ["ArtistRevenueMacApp"],
            path: "Tests"
        ),
    ]
)
