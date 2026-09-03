// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpellChecker",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SpellChecker", targets: ["SpellChecker"])],
    targets: [
        .target(name: "SpellChecker"),
        .testTarget(name: "SpellCheckerTests", dependencies: ["SpellChecker"]),
    ]
)
