// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Lid",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LidCore", targets: ["LidCore"]),
        .executable(name: "lid-sensor", targets: ["LidSensorCLI"]),
        .executable(name: "LidApp", targets: ["LidApp"]),
    ],
    targets: [
        .target(
            name: "LidCore",
            path: "Sources/LidCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .executableTarget(
            name: "LidSensorCLI",
            dependencies: ["LidCore"],
            path: "Sources/LidSensorCLI"
        ),
        .executableTarget(
            name: "LidApp",
            dependencies: ["LidCore"],
            path: "Sources/LidApp",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "LidCoreTests",
            dependencies: ["LidCore"],
            path: "Tests/LidCoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
