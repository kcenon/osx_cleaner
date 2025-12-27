// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "osxcleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "osxcleaner", targets: ["osxcleaner"]),
        .executable(name: "OSXCleanerGUI", targets: ["OSXCleanerGUI"]),
        .library(name: "OSXCleanerKit", targets: ["OSXCleanerKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
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
        // SwiftUI GUI Application
        .executableTarget(
            name: "OSXCleanerGUI",
            dependencies: [
                "OSXCleanerKit"
            ],
            path: "Sources/OSXCleanerGUI"
        ),
        // Rust Core C Bridge
        .systemLibrary(
            name: "COSXCore",
            path: "Sources/COSXCore"
        ),
        // Swift Library with Rust FFI Bridge
        .target(
            name: "OSXCleanerKit",
            dependencies: [
                "COSXCore",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Yams", package: "Yams")
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
