//
//  Parser+Utils.swift
//  Parser
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Source
import Diagnostic
import Lexer

extension Parser {
  func raise(_ diag: Diagnostic) -> Error {
    diagnostics.append(diag)
    return ParserError.emit(diag)
  }

  /// Consumes the given token from the given list, i.e. discard it and move on to the next one. Throws if the current
  /// token being processed isn't equal to the given token.
  ///
  /// - Parameters:
  ///   - token: The token to consume.
  ///   - consumingTrailingNewlines: Whether newline tokens should be consumed after consuming the given token.
  /// - Returns: The token which was consumed.
  /// - Throws: A `ParserError.expectedToken` if the current token being processed isn't equal to the given token.
  @discardableResult
  func consume(_ token: Token.Kind, consumingTrailingNewlines: Bool = true, or diagnostic: Diagnostic) throws -> Token {
    guard let first = currentToken, first.kind == token else {
      throw raise(diagnostic)
    }

    currentIndex += 1

    if consumingTrailingNewlines {
      consumeNewLines()
    }

    return first
  }

  /// Consumes one of the given tokens from the given list, i.e. discard it and move on to the next one. Throws if the
  /// current token being processed isn't equal to any of the given tokens.
  ///
  /// - Parameters:
  ///   - tokens: The tokens that can be consumed.
  ///   - consumingTrailingNewlines: Whether newline tokens should be consumed after consuming the given token.
  /// - Returns: The token which was consumed.
  /// - Throws: A `ParserError.expectedTokens` if the current token being processed isn't equal to the given token.
  @discardableResult
  func consume(anyOf: [Token.Kind], consumingTrailingNewlines: Bool = true, or diagnostic: Diagnostic) throws -> Token {
    guard let first = currentToken, anyOf.contains(first.kind) else {
      throw raise(diagnostic)
    }

    currentIndex += 1

    if consumingTrailingNewlines {
      consumeNewLines()
    }

    return first
  }

  /// Consume newlines tokens up to the first non-newline token.
  func consumeNewLines() {
    while currentIndex < tokens.count, tokens[currentIndex].kind == .newline {
      currentIndex += 1
    }
  }

  /// Wraps the given throwable task, wrapping its return value in an optional. If the task throws, the function returns
  /// `nil`.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: The return value of the task, or `nil` if the task threw.
  func attempt<ReturnType>(_ task: () throws -> ReturnType) -> ReturnType? {
    let nextIndex = self.currentIndex
    let lastDiagnostics = diagnostics
    do {
      return try task()
    } catch {
      self.currentIndex = nextIndex
      self.diagnostics = lastDiagnostics
      return nil
    }
  }

  /// Wraps the given throwable task, wrapping its return value in an optional. If the task throws, the function returns
  /// `nil`.
  ///
  /// **Note:** This function is the same as attempt(task:), but where task is an @autoclosure. Functions cannot be
  /// passed as @autoclosure arguments.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: The return value of the task, or `nil` if the task threw.
  func attempt<ReturnType>(_ task: @autoclosure () throws -> ReturnType) -> ReturnType? {
    let nextIndex = self.currentIndex
    let lastDiagnostics = diagnostics
    do {
      return try task()
    } catch {
      self.currentIndex = nextIndex
      self.diagnostics = lastDiagnostics
      return nil
    }
  }

  /// Finds the index of the first token in `targetTokens` which appears between the current token being processed and
  /// the token at `maxIndex`, at the same semantic nesting depth as the current token.
  ///
  /// E.g., if `targetTokens` is `[')']` and the list of remaining tokens is `f(g())` and `f` has index 0, the function
  /// will return the second `)`'s index, i.e. 5.
  ///
  /// - Parameters:
  ///   - targetTokens: The tokens being searched for.
  ///   - maxIndex: The index of the last token to inspect in the program's tokens.
  /// - Returns: The index of first token in `targetTokens` in the program's tokens.
  func indexOfFirstAtCurrentDepth(_ targetTokens: [Token.Kind], maxIndex: Int? = nil) -> Int? {
    let upperBound = maxIndex ?? tokens.count

    // The depth of the token, for each type of depth.
    var bracketDepth = 0
    var braceDepth = 0
    var squareBracketDepth = 0

    guard currentIndex <= upperBound else { return nil }

    let range = (currentIndex..<upperBound)

    // If the brace depth is negative, the program is malformed.
    for index in range where braceDepth >= 0 {
      let token = tokens[index].kind

      // If we found a limit token and all the depths are 0 (at the same level the initial token was at), return its
      // index.
      if targetTokens.contains(token), bracketDepth == 0, braceDepth == 0, squareBracketDepth == 0 {
        return index
      }

      // Update the depths depending on the token.
      if case .punctuation(let punctuation) = token {
        switch punctuation {
        case .openBracket: bracketDepth += 1
        case .closeBracket: bracketDepth -= 1
        case .openBrace: braceDepth += 1
        case .closeBrace: braceDepth -= 1
        case .openSquareBracket: squareBracketDepth += 1
        case .closeSquareBracket: squareBracketDepth -= 1
        default: continue
        }
      }
    }

    return nil
  }
}
