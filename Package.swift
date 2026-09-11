// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchVeil",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NotchVeil", targets: ["NotchVeil"])],
    targets: [
        .target(name: "NotchVeilCore", resources: [.process("Resources")]),
        .executableTarget(name: "NotchVeil", dependencies: ["NotchVeilCore"]),
        // Standalone regression runner also works with Command Line Tools (without XCTest/Xcode).
        .executableTarget(name: "NotchVeilTests", dependencies: ["NotchVeilCore"], path: "Tests/NotchVeilCoreTests")
    ]
)
