// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpellChecker",
    // AppKit's NSSpellChecker on the Mac, UIKit's UITextChecker everywhere else.
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .visionOS(.v1), .macCatalyst(.v17)],
    products: [.library(name: "SpellChecker", targets: ["SpellChecker"])],
    targets: [
        .target(name: "SpellChecker"),
        .testTarget(name: "SpellCheckerTests", dependencies: ["SpellChecker"]),
    ]
)
