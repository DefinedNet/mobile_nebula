// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MobileNebulaKit",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    .library(name: "MobileNebula", targets: ["MobileNebula"])
  ],
  targets: [
    // Built from nebula/ by gen-artifacts.sh ios, never committed
    .binaryTarget(
      name: "MobileNebula",
      path: "Binaries/MobileNebula.xcframework"
    )
  ]
)
