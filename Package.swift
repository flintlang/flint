// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "etherlang",
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2")
  ],
  targets: [
    .target(
      name: "etherlang",
      dependencies: ["Parser", "SemanticAnalyzer", "IULIABackend", "Diagnostic"]),
    .target(
      name: "AST",
      dependencies: ["Diagnostic"]),
    .target(
      name: "Diagnostic",
      dependencies: []),
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
      name: "IULIABackend",
      dependencies: ["AST", "CryptoSwift"]),
    ]
)
