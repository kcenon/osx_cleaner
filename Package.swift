// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "osxcleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "osxcleaner", targets: ["osxcleaner"]),
        .library(name: "OSXCleanerKit", targets: ["OSXCleanerKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        // CLI Application
        .executableTarget(
            name: "osxcleaner",
            dependencies: [
                "OSXCleanerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/osxcleaner"
        ),
        // Swift Library
        .target(
            name: "OSXCleanerKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/OSXCleanerKit",
            linkerSettings: [
                .unsafeFlags(["-L", "rust-core/target/release"]),
                .linkedLibrary("osxcore")
            ]
        ),
        // Tests
        .testTarget(
            name: "OSXCleanerKitTests",
            dependencies: ["OSXCleanerKit"],
            path: "Tests/OSXCleanerKitTests"
        )
    ]
)
