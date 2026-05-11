// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DripMeter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "DripMeter", targets: ["DripMeter"]),
        .library(name: "DripMeterCore", targets: ["DripMeterCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DripMeterCore",
            path: "Sources/DripMeterCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "DripMeter",
            dependencies: ["DripMeterCore"],
            path: "Sources/DripMeter",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "DripMeterCoreTests",
            dependencies: ["DripMeterCore"],
            path: "Tests/DripMeterCoreTests"
        ),
    ]
)
