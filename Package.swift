// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "DynamicUI", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "DynamicUICore", targets: ["DynamicUICore"])], targets: [.target(name: "DynamicUICore", resources: [.process("Fixtures")]), .testTarget(name: "DynamicUICoreTests", dependencies: ["DynamicUICore"])])
