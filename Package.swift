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
      dependencies: ["Parser", "SemanticAnalyzer", "IULIABackend"]),
    .target(
      name: "AST",
      dependencies: []),
    .target(
      name: "Parser",
      dependencies: ["AST"]),
    .testTarget(
      name: "ParserTests",
      dependencies: ["Parser"]),
    .target(
      name: "SemanticAnalyzer",
      dependencies: ["AST"]),
    .testTarget(
      name: "SemanticAnalyzerTests",
      dependencies: ["SemanticAnalyzer, Tokenizer, Parser"]),
    .target(
      name: "IULIABackend",
      dependencies: ["AST", "CryptoSwift"]),
    ]
)
