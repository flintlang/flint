//
//  Tokenizer
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import AST
import Diagnostic

public struct Tokenizer {
  var inputFile: URL
  
  public init(inputFile: URL) {
    self.inputFile = inputFile
  }
  
  public func tokenize() -> [Token] {
    let code = try! String(contentsOf: inputFile, encoding: .utf8)
    return tokenize(string: code)
  }

  func tokenize(string: String) -> [Token] {
    let components = splitOnPunctuation(string: string)

    var tokens = [Token]()

    for (component, sourceLocation) in components {
      if component == " " {
        continue
      } else if let token = syntaxMap[component] {
        tokens.append(token)
      } else if let num = Int(component) {
        let lastTwoTokens = tokens[tokens.count-2..<tokens.count]
        if case .literal(.decimal(.integer(let base))) = lastTwoTokens.first!, lastTwoTokens.last! == .binaryOperator(.dot) {
          tokens[tokens.count-2] = .literal(.decimal(.real(base, num)))
          tokens.removeLast()
        } else {
          tokens.append(.literal(.decimal(.integer(num))))
        }
      } else if let first = component.first, let last = component.last, first == "\"", first == last {
        tokens.append(.literal(.string(String(component[(component.index(after: component.startIndex)..<component.index(before: component.endIndex))]))))
      } else {
        tokens.append(.identifier(component))
      }
    }

    return tokens
  }

  let syntaxMap: [String: Token] = [
    "\n": .newline,
    "contract": .contract,
    "var": .var,
    "func": .func,
    "mutating": .mutating,
    "return": .return,
    "public": .public,
    "if": .if,
    "else": .else,
    "+": .binaryOperator(.plus),
    "-": .binaryOperator(.minus),
    "*": .binaryOperator(.times),
    "/": .binaryOperator(.divide),
    "=": .binaryOperator(.equal),
    ".": .binaryOperator(.dot),
    "<": .binaryOperator(.lessThan),
    "<=": .binaryOperator(.lessThanOrEqual),
    ">": .binaryOperator(.greaterThan),
    ">=": .binaryOperator(.greaterThanOrEqual),
    "{": .punctuation(.openBrace),
    "}": .punctuation(.closeBrace),
    ":": .punctuation(.colon),
    "::": .punctuation(.doubleColon),
    "(": .punctuation(.openBracket),
    ")": .punctuation(.closeBracket),
    "->": .punctuation(.arrow),
    ",": .punctuation(.comma),
    ";": .punctuation(.semicolon),
    "true": .literal(.boolean(.true)),
    "false": .literal(.boolean(.false))
  ]

  func splitOnPunctuation(string: String) -> [(String, SourceRange)] {
    var components = [(String, SourceRange)]()
    var acc = ""

    var inStringLiteral = false

    var line = 1
    var column = 1

    for char in string {
      if char == "\"" {
        inStringLiteral = !inStringLiteral
        acc += String(char)
      } else if inStringLiteral {
        acc += String(char)
      } else if CharacterSet.alphanumerics.contains(char.unicodeScalars.first!) {
        acc += String(char)
      } else {
        if !acc.isEmpty {
          components.append((acc, SourceRange(line: line, column: column - acc.count, length: acc.count)))
          acc = ""
        }

        if let (last, sourceLocation) = components.last {
          if last == ":", char == ":" {
            components[components.endIndex.advanced(by: -1)] = ("::", sourceLocation)
            continue
          } else if last == "-", char == ">" {
            components[components.endIndex.advanced(by: -1)] = ("->", sourceLocation)
            continue
          }
        }

        components.append((String(char), SourceRange(line: line, column: column, length: 1)))
      }

      column += 1

      if CharacterSet.newlines.contains(char.unicodeScalars.first!) {
        line += 1
        column = 1
      }
    }

    components.append((acc, SourceRange(line: line, column: column - acc.count, length: acc.count)))
    return components.filter { !$0.0.isEmpty }
  }

}
