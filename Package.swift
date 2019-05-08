// swift-tools-version:4.2

import PackageDescription

let package = Package(
  name: "flintc",
  products: [
    .executable(
      name: "flintc",
      targets: [
        "flintc",
      ]
    ),
    .executable(
      name: "lite",
      targets: [
        "lite",
      ]
    ),
    .executable(
      name: "file-check",
      targets: [
        "file-check",
      ]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
    .package(url: "https://github.com/kylef/Commander", from: "0.8.0"),
    .package(url: "https://github.com/llvm-swift/Lite.git", from: "0.0.3"),
    .package(url: "https://github.com/llvm-swift/FileCheck.git", from: "0.0.4"),
    .package(url: "https://github.com/llvm-swift/Symbolic.git", from: "0.0.1"),
    .package(url: "https://github.com/flintrocks/Cuckoo.git", .branch("master")),
  ],
  targets: [
    // MARK: Source -
    .target(
      name: "flint-lsp",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "LSP", "Compiler"]),
    .target(
      name: "flint-ca",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "ContractAnalysis", "Compiler"]),
    .target(
      name: "flint-test",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "JSTranslator", "Compiler"]),
    .target(
      name: "flint-repl",
      dependencies: ["Commander", "Rainbow", "Symbolic", "Diagnostic", "REPL"]),
    .target(
      name: "Source",
      dependencies: []
    ),
    .testTarget(
      name: "SourceTests",
      dependencies: [
        "Source",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Source"]
    ),
    // MARK: Compiler -
    .target(
      name: "Compiler",
      dependencies: [
        "Parser",
        "Lexer",
        "ASTPreprocessor",
        "SemanticAnalyzer",
        "TypeChecker",
        "Optimizer",
        "IRGen",
        "Commander",
        "Rainbow",
        "Symbolic",
        "Diagnostic",
      ]
    ),
    .testTarget(
      name: "CompilerTests",
      dependencies: [
        "Compiler",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Compiler"]
    ),
    // MARK: Diagnostic -
    .target(
      name: "Diagnostic",
      dependencies: [
        "Source",
        "Rainbow",
        "Utils",
      ]
    ),
    .testTarget(
      name: "DiagnosticTests",
      dependencies: [
        "Diagnostic",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Diagnostic"]
    ),
    // MARK: Lexer -
    .target(
      name: "Lexer",
      dependencies: [
        "Source",
        "Diagnostic",
      ]
    ),
    .testTarget(
      name: "LexerTests",
      dependencies: [
        "Lexer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Lexer"]
    ),
    // MARK: AST -
    .target(
      name: "AST",
      dependencies: [
        "Source",
        "Diagnostic",
        "Lexer",
        "ABI",
      ],
      exclude: ["ASTPass/ASTPass.template.swift"]
    ),
    .testTarget(
      name: "ASTTests",
      dependencies: [
        "AST",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/AST"]
    ),
    // MARK: Parser -
    .target(
      name: "Parser",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Lexer",
      ]
    ),
    .testTarget(
      name: "ParserTests",
      dependencies: [
        "Parser",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Parser"]
    ),
    // MARK: SemanticAnalyzer -
    .target(
      name: "SemanticAnalyzer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
      ]
    ),
    .testTarget(
      name: "SemanticAnalyzerTests",
      dependencies: [
        "SemanticAnalyzer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/SemanticAnalyzer"]
    ),
    // MARK: ASTPreprocessor -
    .target(
      name: "ASTPreprocessor",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST"
      ]
    ),
    .testTarget(
      name: "ASTPreprocessorTests",
      dependencies: [
        "ASTPreprocessor",
        "Cuckoo",
        ],
      sources: [".", "../../.derived-tests/ASTPreprocessor"]
    ),
    // MARK: TypeChecker -
    .target(
      name: "TypeChecker",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
      ]
    ),
    .testTarget(
      name: "TypeCheckerTests",
      dependencies: [
        "TypeChecker",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/TypeChecker"]
    ),
    // MARK: Optimizer -
    .target(
      name: "Optimizer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
      ]
    ),
    .testTarget(
      name: "OptimizerTests",
      dependencies: [
        "Optimizer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Optimizer"]
    ),
    // MARK: IRGen -
    .target(
      name: "IRGen",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "CryptoSwift",
        "YUL",
        "Utils",
      ]
    ),
    .testTarget(
      name: "IRGenTests",
      dependencies: [
        "IRGen",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/IRGen"]
    ),
    // MARK: YUL -
    .target(
      name: "YUL",
      dependencies: [
        "Utils",
      ]
    ),
    // MARK: ABI -
    .target(
      name: "ABI",
      dependencies: [
        "Source",
        "CryptoSwift",
      ]
    ),
    .testTarget(
      name: "ABITests",
      dependencies: [
        "ABI",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/ABI"]
    ),
    // MARK: Utils -
    .target(
      name: "Utils",
      dependencies: []
    ),
    .testTarget(
      name: "UtilsTests",
      dependencies: [
        "Utils",
        "Cuckoo"
      ],
      sources: [".", "../../.derived-tests/Utils"]
    ),
    // MARK: flintc -
    .target(
      name: "flintc",
      dependencies: [
        "Compiler",
      ]
    ),
    // MARK: lite -
    .target(
        name: "lite",
        dependencies: [
          "LiteSupport",
          "Rainbow",
          "Symbolic",
      ]
    ),
    // MARK: file-check
    .target(
        name: "file-check",
        dependencies: ["FileCheck", "Commander"]),
    .target(
        name: "LSP",
        dependencies: ["Diagnostic", "AST"]),
    .target(
        name: "ContractAnalysis",
        dependencies: ["AST"]),
    .target(
        name: "JSTranslator",
        dependencies: ["AST", "Parser", "Lexer"]),
    .target(
        name: "REPL",
        dependencies: ["AST", "Parser", "Lexer", "Compiler"])
    ]
)
