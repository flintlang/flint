//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import Parser
import SemanticAnalyzer
import IULIABackend
import Diagnostic

struct Compiler {
  var inputFile: URL
  
  func compile() -> String {
    let sourceCode = try! String(contentsOf: inputFile, encoding: .utf8)
    
    let tokens = Tokenizer(sourceCode: sourceCode).tokenize()
    let (parserAST, context, diagnostics) = Parser(tokens: tokens).parse()

    print(tokens)
    print("\n\n")
    print(DiagnosticsFormatter(diagnostics: diagnostics, sourceCode: sourceCode, fileName: inputFile.lastPathComponent).rendered())

    guard let ast = parserAST else {
      exit(1)
    }
    print(ast)

    try! SemanticAnalyzer(ast: ast, context: context).analyze()
    return IULIABackend(topLevelModule: ast).generateCode()
  }
}
