// swift-tools-version:4.2

import PackageDescription

let package = Package(
  name: "flintc",
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
    .package(url: "https://github.com/kylef/Commander", from: "0.8.0"),
    .package(url: "https://github.com/llvm-swift/Lite.git", from: "0.0.3"),
    .package(url: "https://github.com/llvm-swift/FileCheck.git", from: "0.0.4"),
    .package(url: "https://github.com/llvm-swift/Symbolic.git", from: "0.0.1"),
    .package(url: "https://github.com/theguild/json-swift.git", from: "4.0.0"),
    .package(url: "https://github.com/theguild/swift-lsp.git", from: "4.0.0"),
  ],
  targets: [
    .target(
      name: "flintc",
      dependencies: ["Compiler"]),
    .target(
      name: "Source",
      dependencies: []
    ),
    .target(
      name: "Compiler",
      dependencies: [
        "Parser",
        "Lexer",
        "SemanticAnalyzer",
        "TypeChecker",
        "Optimizer",
        "IRGen",
        "Commander",
        "Rainbow",
        "Symbolic",
        "Diagnostic"]),
    .target(
      name: "Diagnostic",
      dependencies: [
        "Source", "Rainbow"
        ]
    ),
    .target(
      name: "Lexer",
      dependencies: [
        "Source",
        "Diagnostic",
        ]
    ),
    .target(
      name: "AST",
      dependencies: [
        "Source",
        "Diagnostic",
        "Lexer",
      ],
      exclude: ["ASTPass/ASTPass.template.swift"],
      sources: [".", "../../.derived-sources/AST"]
    ),
    .target(
      name: "Parser",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Lexer"
      ]),
    .target(
      name: "SemanticAnalyzer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST"
      ]
    ),
    .target(
      name: "TypeChecker",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST"
      ]
    ),
    .target(
      name: "Optimizer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST"
      ]
    ),
    .target(
        name: "IRGen",
        dependencies: [
          "Source",
          "Diagnostic",
          "AST",
          "CryptoSwift"
      ]
    ),
    .target(
        name: "lite",
        dependencies: ["LiteSupport", "Rainbow", "Symbolic"]),
    .target(
        name: "file-check",
        dependencies: ["FileCheck", "Commander"]),
    .target(
        name: "langsrv",
        dependencies: ["Compiler", "JSONLib", "LanguageServerProtocol", "JsonRpcProtocol"],
        path: "Sources/LSP/langsrv")
    ]
)
