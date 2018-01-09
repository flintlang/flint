// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "etherlang",
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
    .package(url: "https://github.com/kylef/Commander", from: "0.8.0"),
    .package(url: "https://github.com/llvm-swift/Lite.git", from: "0.0.3"),
    .package(url: "https://github.com/llvm-swift/FileCheck.git", from: "0.0.4"),
    .package(url: "https://github.com/llvm-swift/Symbolic.git", from: "0.0.1")
  ],
  targets: [
    .target(
      name: "etherlang",
      dependencies: ["Parser", "SemanticAnalyzer", "IRGen", "Diagnostic", "Commander"]),
    .target(
      name: "AST",
      dependencies: []),
    .target(
      name: "Diagnostic",
      dependencies: ["Rainbow", "AST"]),
    .target(
      name: "Parser",
      dependencies: ["AST", "Diagnostic"]),
    .target(
      name: "SemanticAnalyzer",
      dependencies: ["AST", "Diagnostic"]),
    .target(
        name: "IRGen",
        dependencies: ["AST", "CryptoSwift"]),
    .target(
        name: "lite",
        dependencies: ["LiteSupport", "Rainbow", "Symbolic"]),
    .target(
        name: "file-check",
        dependencies: ["FileCheck", "Commander"])

    ]
)
