// swift-tools-version: 5.10
import PackageDescription

// Placeholder until Scripts/FetchIOSCore.sh (or local core build) populates ByVpnCore.
let package = Package(
    name: "ByVpnCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "ByVpnCore", targets: ["ByVpnCore"])
    ],
    targets: [
        .target(name: "ByVpnCore", path: "Sources/ByVpnCore")
    ]
)
