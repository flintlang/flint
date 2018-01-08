// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "etherlang",
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    .package(url: "https://github.com/kylef/Commander", from: "0.8.0")
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
    .testTarget(
      name: "ParserTests",
      dependencies: ["Parser"]),
    .target(
      name: "SemanticAnalyzer",
      dependencies: ["AST", "Diagnostic"]),
    .testTarget(
      name: "SemanticAnalyzerTests",
      dependencies: ["SemanticAnalyzer", "Parser"]),
    .target(
      name: "IRGen",
      dependencies: ["AST", "CryptoSwift"]),
    ]
)
