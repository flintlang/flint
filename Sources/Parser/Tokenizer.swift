//
//  Tokenizer
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import AST

/// The tokenizer, which turns the source code into a list of tokens.
public struct Tokenizer {
  /// The original source code of the Flint program.
  var sourceCode: String
  
  public init(sourceCode: String) {
    self.sourceCode = sourceCode
  }
  
  /// Converts the source code into a list of tokens.
  public func tokenize() -> [Token] {
    return tokenize(string: sourceCode)
  }

  func tokenize(string: String) -> [Token] {
    // Split the source code string based on whitespace and other punctuation.
    let components = splitOnPunctuation(string: string)

    var tokens = [Token]()

    for (component, sourceLocation) in components {
      // Skip whitespace.
      if component == " " {
        continue
      } else if let token = syntaxMap[component] {
        // The token is punctuation or a keyword.
        tokens.append(Token(kind: token, sourceLocation: sourceLocation))
      } else if let num = Int(component) {
        // The token is a number literal.
        let lastTwoTokens = tokens[tokens.count-2..<tokens.count]

        if case .literal(.decimal(.integer(let base))) = lastTwoTokens.first!.kind, lastTwoTokens.last!.kind == .punctuation(.dot) {
          tokens[tokens.count-2] = Token(kind: .literal(.decimal(.real(base, num))), sourceLocation: sourceLocation)
          tokens.removeLast()
        } else {
          tokens.append(Token(kind: .literal(.decimal(.integer(num))), sourceLocation: sourceLocation))
        }
      } else if let first = component.first, let last = component.last, first == "\"", first == last {
        // The token is a string literal.
        tokens.append(Token(kind: .literal(.string(String(component[(component.index(after: component.startIndex)..<component.index(before: component.endIndex))]))), sourceLocation: sourceLocation))
      } else if component.first == "@" {
        // The token is a function attribute.
        tokens.append(Token(kind: .attribute(String(component.dropFirst())), sourceLocation: sourceLocation))
      } else {
        // The token is an identifier.
        tokens.append(Token(kind: .identifier(component), sourceLocation: sourceLocation))
      }
    }

    return tokens
  }

  /// Mapping between strings and their token, for tokens which are not a literal or an identifier.
  let syntaxMap: [String: Token.Kind] = [
    "\n": .newline,
    "contract": .contract,
    "struct": .struct,
    "var": .var,
    "let": .let,
    "func": .func,
    "mutating": .mutating,
    "return": .return,
    "public": .public,
    "if": .if,
    "else": .else,
    "self": .self,
    "implicit": .implicit,
    "inout": .inout,
    "+": .punctuation(.plus),
    "-": .punctuation(.minus),
    "*": .punctuation(.times),
    "/": .punctuation(.divide),
    "=": .punctuation(.equal),
    "+=": .punctuation(.plusEqual),
    "-=": .punctuation(.minusEqual),
    "*=": .punctuation(.timesEqual),
    "/=": .punctuation(.divideEqual),
    ".": .punctuation(.dot),
    "&": .punctuation(.ampersand),
    "<": .punctuation(.openAngledBracket),
    "<=": .punctuation(.lessThanOrEqual),
    ">": .punctuation(.closeAngledBracket),
    ">=": .punctuation(.greaterThanOrEqual),
    "||": .punctuation(.or),
    "&&": .punctuation(.and),
    "==": .punctuation(.doubleEqual),
    "!=": .punctuation(.notEqual),
    "{": .punctuation(.openBrace),
    "}": .punctuation(.closeBrace),
    "[": .punctuation(.openSquareBracket),
    "]": .punctuation(.closeSquareBracket),
    ":": .punctuation(.colon),
    "::": .punctuation(.doubleColon),
    "(": .punctuation(.openBracket),
    ")": .punctuation(.closeBracket),
    "->": .punctuation(.arrow),
    "<-": .punctuation(.leftArrow),
    ",": .punctuation(.comma),
    ";": .punctuation(.semicolon),
    "//": .punctuation(.doubleSlash),
    "true": .literal(.boolean(.true)),
    "false": .literal(.boolean(.false))
  ]

  /// Splits the given string based on whitespace and other punctuation.
  ///
  /// - Parameter string: The string to split.
  /// - Returns: A list of pairs containing each component and their source location.
  func splitOnPunctuation(string: String) -> [(String, SourceLocation)] {
    var components = [(String, SourceLocation)]()

    // The current string component we are processing.
    var acc = ""

    var inStringLiteral = false

    var line = 1
    var column = 1

    var inComment = false

    for char in string {
      if inComment {
        // If we're in a comment, discard the characters up to a newline.
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
      } else if CharacterSet.alphanumerics.contains(char.unicodeScalars.first!) || char == "@" {
        acc += String(char)
      } else {
        if !acc.isEmpty {
          // Add the component to the list and reset.
          components.append((acc, SourceLocation(line: line, column: column - acc.count, length: acc.count)))
          acc = ""
        }

        // If the last component and the new one can be merged, merge them.
        if let (last, sourceLocation) = components.last, canBeMerged(last, String(char)) {
          let sourceLocation = SourceLocation(line: sourceLocation.line, column: sourceLocation.column, length: sourceLocation.length + 1)
          components[components.endIndex.advanced(by: -1)] = ("\(last)\(char)", sourceLocation)
          column += 1

          if components.last!.0 == "//" {
            // We're in a comment. Remove "//" from the list of components.
            components.removeLast()
            inComment = true
          }

          continue
        }

        // The character is a newline.
        components.append((String(char), SourceLocation(line: line, column: column, length: 1)))
      }

      column += 1

      if CharacterSet.newlines.contains(char.unicodeScalars.first!) {
        line += 1
        column = 1
      }
    }

    components.append((acc, SourceLocation(line: line, column: column - acc.count, length: acc.count)))

    // Remove empty string components.
    return components.filter { !$0.0.isEmpty }
  }

  /// Indicates whether two string components can be merged to form a single component.
  /// For example, `/` and `/` can be merged to form `//`.
  ///
  /// - Returns: Whether `component1` and `component2` can be merged.
  func canBeMerged(_ component1: String, _ component2: String) -> Bool {
    let mergeable = syntaxMap.keys.filter { $0.count == 2 }
    return mergeable.contains { $0 == component1 + component2 }
  }
}
