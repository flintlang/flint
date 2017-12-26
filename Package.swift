// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "etherlang",
  dependencies: [],
  targets: [
    .target(
      name: "etherlang",
      dependencies: ["Parser"]),
    .target(
      name: "Parser",
      dependencies: []),
    .testTarget(
      name: "ParserTests",
      dependencies: ["Parser"]),
    ]
)
