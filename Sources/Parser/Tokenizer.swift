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
  var sourceCode: String
  
  public init(sourceCode: String) {
    self.sourceCode = sourceCode
  }
  
  public func tokenize() -> [Token] {
    return tokenize(string: sourceCode)
  }

  func tokenize(string: String) -> [Token] {
    let components = splitOnPunctuation(string: string)

    var tokens = [Token]()

    for (component, sourceLocation) in components {
      if component == " " {
        continue
      } else if let token = syntaxMap[component] {
        tokens.append(Token(kind: token, sourceLocation: sourceLocation))
      } else if let num = Int(component) {
        let lastTwoTokens = tokens[tokens.count-2..<tokens.count]
        if case .literal(.decimal(.integer(let base))) = lastTwoTokens.first!.kind, lastTwoTokens.last!.kind == .binaryOperator(.dot) {
          tokens[tokens.count-2] = Token(kind: .literal(.decimal(.real(base, num))), sourceLocation: sourceLocation)
          tokens.removeLast()
        } else {
          tokens.append(Token(kind: .literal(.decimal(.integer(num))), sourceLocation: sourceLocation))
        }
      } else if let first = component.first, let last = component.last, first == "\"", first == last {
        tokens.append(Token(kind: .literal(.string(String(component[(component.index(after: component.startIndex)..<component.index(before: component.endIndex))]))), sourceLocation: sourceLocation))
      } else {
        tokens.append(Token(kind: .identifier(component), sourceLocation: sourceLocation))
      }
    }

    return tokens
  }

  let syntaxMap: [String: Token.Kind] = [
    "\n": .newline,
    "contract": .contract,
    "var": .var,
    "func": .func,
    "mutating": .mutating,
    "return": .return,
    "public": .public,
    "if": .if,
    "else": .else,
    "self": .self,
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
    "[": .punctuation(.openSquareBracket),
    "]": .punctuation(.closeSquareBracket),
    ":": .punctuation(.colon),
    "::": .punctuation(.doubleColon),
    "(": .punctuation(.openBracket),
    ")": .punctuation(.closeBracket),
    "->": .punctuation(.arrow),
    ",": .punctuation(.comma),
    ";": .punctuation(.semicolon),
    "//": .punctuation(.doubleSlash),
    "true": .literal(.boolean(.true)),
    "false": .literal(.boolean(.false))
  ]

  func splitOnPunctuation(string: String) -> [(String, SourceLocation)] {
    var components = [(String, SourceLocation)]()
    var acc = ""

    var inStringLiteral = false

    var line = 1
    var column = 1

    var inComment = false

    for char in string {

      if inComment {
        if CharacterSet.newlines.contains(char.unicodeScalars.first!) {
          inComment = false
          line += 1
          column = 1
        }
        continue
      }

      if char == "\"" {
        inStringLiteral = !inStringLiteral
        acc += String(char)
      } else if inStringLiteral {
        acc += String(char)
      } else if CharacterSet.alphanumerics.contains(char.unicodeScalars.first!) {
        acc += String(char)
      } else {
        if !acc.isEmpty {
          components.append((acc, SourceLocation(line: line, column: column - acc.count, length: acc.count)))
          acc = ""
        }

        if let (last, sourceLocation) = components.last, canBeMerged(last, String(char)) {
          components[components.endIndex.advanced(by: -1)] = ("\(last)\(char)", SourceLocation(line: sourceLocation.line, column: sourceLocation.column, length: sourceLocation.length + 1))
          column += 1

          if components.last!.0 == "//" {
            components.removeLast()
            inComment = true
          }

          continue
        }

        components.append((String(char), SourceLocation(line: line, column: column, length: 1)))
      }

      column += 1

      if CharacterSet.newlines.contains(char.unicodeScalars.first!) {
        line += 1
        column = 1
      }
    }

    components.append((acc, SourceLocation(line: line, column: column - acc.count, length: acc.count)))
    return components.filter { !$0.0.isEmpty }
  }

  func canBeMerged(_ component1: String, _ component2: String) -> Bool {
    let mergeable = [(":", ":"), ("-", ">"), ("/", "/")]
    return mergeable.contains { $0 == (component1, component2) }
  }
}
