// swift-tools-version: 6.0
import PackageDescription

// The Swift sgit vault reader (contracts §5). Owned by the vault session;
// this is the platform session's compiling skeleton, to be replaced.
let package = Package(
    name: "SGitVault",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SGitVault", targets: ["SGitVault"]),
    ],
    targets: [
        .target(name: "SGitVault"),
        .testTarget(name: "SGitVaultTests", dependencies: ["SGitVault"]),
    ]
)
