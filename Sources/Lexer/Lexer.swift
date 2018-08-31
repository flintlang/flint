//
//  Lexer.swift
//  Lexer
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import Foundation
import Source

/// The lexer, which turns the source code into a list of tokens.
public struct Lexer {
  /// The URL of the source file of the Flint program.
  var sourceFile: URL

  /// The original source code of the Flint program.
  var sourceCode: String

  var isFromStdlib: Bool

  public init(sourceFile: URL, isFromStdlib: Bool = false) {
    self.sourceFile = sourceFile
    self.sourceCode = try! String(contentsOf: sourceFile)
    self.isFromStdlib = isFromStdlib
  }

  /// Converts the source code into a list of tokens.
  public func lex() -> [Token] {
    return lex(string: sourceCode)
  }

  func lex(string: String) -> [Token] {
    // Split the source code string based on whitespace and other punctuation.
    let components = splitOnPunctuation(string: string)

    var tokens = [Token]()

    for (component, sourceLocation) in components {
      // Skip whitespace.
      if component.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
        continue
      } else if let token = syntaxMap[component] {
        // The token is punctuation or a keyword.
        tokens.append(Token(kind: token, sourceLocation: sourceLocation))
      } else if let num = toInt(component) {
        // The token is a number literal.
        let lastTwoTokens = tokens[tokens.count-2..<tokens.count]

        if case .literal(.decimal(.integer(let base))) = lastTwoTokens.first!.kind, lastTwoTokens.last!.kind == .punctuation(.dot) {
          tokens[tokens.count-2] = Token(kind: .literal(.decimal(.real(base, num))), sourceLocation: sourceLocation)
          tokens.removeLast()
        } else {
          tokens.append(Token(kind: .literal(.decimal(.integer(num))), sourceLocation: sourceLocation))
        }
      } else if component.hasPrefix("0x") {
        // The token is an address literal.
        let hex = component.replacingOccurrences(of: "_", with: "")
        tokens.append(Token(kind: .literal(.address(hex)), sourceLocation: sourceLocation))
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
    "enum": .enum,
    "case": .case,
    "var": .var,
    "let": .let,
    "func": .func,
    "init": .init,
    "fallback": .fallback,
    "try": .try,
    "mutating": .mutating,
    "return": .return,
    "become": .become,
    "public": .public,
    "visible": .visible,
    "if": .if,
    "else": .else,
    "for": .for,
    "in": .in,
    "self": .self,
    "implicit": .implicit,
    "inout": .inout,
    "+": .punctuation(.plus),
    "&+": .punctuation(.overflowingPlus),
    "-": .punctuation(.minus),
    "&-": .punctuation(.overflowingMinus),
    "*": .punctuation(.times),
    "&*": .punctuation(.overflowingTimes),
    "**": .punctuation(.power),
    "/": .punctuation(.divide),
    "=": .punctuation(.equal),
    "+=": .punctuation(.plusEqual),
    "-=": .punctuation(.minusEqual),
    "*=": .punctuation(.timesEqual),
    "/=": .punctuation(.divideEqual),
    ".": .punctuation(.dot),
    "..": .punctuation(.dotdot),
    "..<": .punctuation(.halfOpenRange),
    "...": .punctuation(.closedRange),
    "&": .punctuation(.ampersand),
    "!": .punctuation(.bang),
    "?": .punctuation(.question),
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
    "@": .punctuation(.at),
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
          components.append(("\n", sourceLocation(line: line, column: column, length: 1)))

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
      } else if identifierChars.contains(char.unicodeScalars.first!) || char == "@" || char == "_" {
        acc += String(char)
      } else {
        if !acc.isEmpty {
          // Add the component to the list and reset.
          components.append((acc, sourceLocation(line: line, column: column - acc.count, length: acc.count)))
          acc = ""
        }

        // If the last component and the new one can be merged, merge them.
        if let (last, loc) = components.last, canBeMerged(last, String(char)) {
          let loc = sourceLocation(line: loc.line, column: loc.column, length: loc.length + 1)
          components[components.endIndex.advanced(by: -1)] = ("\(last)\(char)", loc)
          column += 1

          if components.last!.0 == "//" {
            // We're in a comment. Remove "//" from the list of components.
            components.removeLast()
            inComment = true
          }

          continue
        }

        // Add the new character directly to the components.
        components.append((String(char), sourceLocation(line: line, column: column, length: 1)))
      }

      column += 1

      // The character is a newline.
      if CharacterSet.newlines.contains(char.unicodeScalars.first!) {
        line += 1
        column = 1
      }
    }

    components.append((acc, sourceLocation(line: line, column: column - acc.count, length: acc.count)))

    // Remove empty string components.
    return components.filter { !$0.0.isEmpty }
  }

  /// The set of characters which can be used in identifiers.
  var identifierChars: CharacterSet {
    return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "$"))
  }

  /// Indicates whether two string components can be merged to form a single component.
  /// For example, `/` and `/` can be merged to form `//`.
  ///
  /// - Returns: Whether `component1` and `component2` can be merged.
  func canBeMerged(_ component1: String, _ component2: String) -> Bool {
    return syntaxMap.keys.contains { $0 == component1 + component2 }
  }

  func toInt(_ component: String) -> Int? {
    let stripped = component.replacingOccurrences(of: "_", with: "")
    return Int(stripped)
  }

  /// Creates a source location for the current file.
  func sourceLocation(line: Int, column: Int, length: Int) -> SourceLocation {
    return SourceLocation(line: line, column: column, length: length, file: sourceFile, isFromStdlib: isFromStdlib)
  }
}
