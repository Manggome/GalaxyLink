// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FoldLink", platforms: [.macOS(.v13)], products: [.executable(name: "FoldLink", targets: ["FoldLink"])], targets: [.executableTarget(name: "FoldLink"), .testTarget(name: "FoldLinkTests", dependencies: ["FoldLink"])])
