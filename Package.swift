// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("ImmutableWeakCaptures"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .strictMemorySafety()
]

let package = Package(
  name: "NavDataDistribution",
  defaultLocalization: "en",
  platforms: [.iOS(.v27), .macOS(.v27)],
  products: [
    .library(name: "NavDataSchema", targets: ["NavDataSchema"]),
    .executable(name: "navdata-store-builder", targets: ["navdata-store-builder"])
  ],
  dependencies: [
    .package(url: "https://github.com/1024jp/GzipSwift", from: "7.0.0"),
    .package(url: "https://github.com/RISCfuture/StreamingLZMA", branch: "main"),
    .package(url: "https://github.com/riscfuture/swiftr2", branch: "main"),
    .package(url: "https://github.com/apple/swift-log", from: "1.15.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2")
  ],
  targets: [
    .target(name: "NavDataSchema", swiftSettings: swiftSettings),
    .target(
      name: "StoreBuilding",
      dependencies: [
        "NavDataSchema",
        .product(name: "Gzip", package: "GzipSwift"),
        .product(name: "StreamingLZMAXZ", package: "StreamingLZMA"),
        .product(name: "SwiftR2", package: "swiftr2"),
        .product(name: "Logging", package: "swift-log")
      ],
      swiftSettings: swiftSettings
    ),
    .executableTarget(
      name: "navdata-store-builder",
      dependencies: [
        "StoreBuilding",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "NavDataSchemaTests",
      dependencies: ["NavDataSchema"],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "StoreBuildingTests",
      dependencies: [
        "NavDataSchema",
        "StoreBuilding",
        .product(name: "Gzip", package: "GzipSwift"),
        .product(name: "StreamingLZMAXZ", package: "StreamingLZMA"),
        .product(name: "Logging", package: "swift-log")
      ],
      resources: [.copy("Fixtures")],
      swiftSettings: swiftSettings
    )
  ],
  swiftLanguageModes: [.v6]
)
