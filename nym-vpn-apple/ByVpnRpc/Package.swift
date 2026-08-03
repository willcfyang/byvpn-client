// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "ByVpnRpc",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ByVpnRpc", targets: ["ByVpnRpc"])],
    targets: [.target(name: "ByVpnRpc", path: "Sources/ByVpnRpc")]
)
