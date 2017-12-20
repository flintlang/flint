//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import Parser

struct Compiler {
   var inputFile: URL

   func compile() -> String {
      let tokens = Tokenizer(inputFile: inputFile).tokenize()
      print(tokens)
      let ast = try! Parser(tokens: tokens).parse()
      print(ast)
      return ""
   }
}
