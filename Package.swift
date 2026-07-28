// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "stripgauge",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: no AppKit, so it is testable without a Touch Bar.
        .target(name: "StripGaugeCore"),
        // Thin shell: argv dispatch plus the AppKit and private-API layers.
        .executableTarget(name: "stripgauge", dependencies: ["StripGaugeCore"]),
        .testTarget(name: "StripGaugeCoreTests", dependencies: ["StripGaugeCore"]),
    ]
)
