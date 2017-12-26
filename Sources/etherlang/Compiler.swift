//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import Parser
import SemanticAnalyzer

struct Compiler {
  var inputFile: URL
  
  func compile() -> String {
    let tokens = Tokenizer(inputFile: inputFile).tokenize()
    let (ast, context) = try! Parser(tokens: tokens).parse()
    try! SemanticAnalyzer(ast: ast, context: context).analyze()
    return ""
  }
}
