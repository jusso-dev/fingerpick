// swift-tools-version: 6.0
import PackageDescription

// Pure game logic: no UIKit or SwiftUI, so it runs and tests on macOS as well as iOS.
let package = Package(
    name: "FingerPickKit",
    defaultLocalization: "en-AU",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FingerPickKit", targets: ["FingerPickKit"]),
    ],
    targets: [
        .target(name: "FingerPickKit"),
        .testTarget(name: "FingerPickKitTests", dependencies: ["FingerPickKit"]),
    ]
)
