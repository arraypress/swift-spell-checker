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

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
