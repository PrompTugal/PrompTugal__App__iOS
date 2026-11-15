// swift-tools-version: 6.0
// PTTalk: the app's transport to the conductor's append lane (signed, sealed with PTLanes' sgit hybrid envelope,
// in parts, with retries) and two composers on it: a note with a screenshot or photo, and a contribution (photo,
// video or recorded interview with an on-device transcript) as a draft for a town. PTPlaces' comments use
// TalkTransport.
// Ported in part from VoiceDebrief (github.com/VoiceDebrief/VoiceDebrief__App__iOS, Apache 2.0): see NOTICE.md.
// Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTTalk",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTTalk", targets: ["PTTalk"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTLanes"),
    ],
    targets: [
        .target(
            name: "PTTalk",
            dependencies: [
                .product(name: "PTCore", package: "PTCore"),
                .product(name: "PTLanes", package: "PTLanes"),
            ]
        ),
        .testTarget(
            name: "PTTalkTests",
            dependencies: ["PTTalk", .product(name: "PTLanes", package: "PTLanes")],
            path: "Tests/PTTalkTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
