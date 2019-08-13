//
//  DiagnosticsVerifier.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/11/18.
//

// This is inspired by https://github.com/silt-lang/silt/blob/master/Sources/Drill/DiagnosticVerifier.swift

import Foundation
import Source

/// Verifies the diagnostics emitted by a program matches exactly what was expected.
/// The expected diagnostics are specified inline in the source file.
public struct DiagnosticsVerifier {
  // swiftlint:disable force_try
  private let diagnosticRegex =
      try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*\\s+\\{\\{(.*)\\}\\}")
  private let diagnosticLineRegex =
      try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*@(\\d+)\\s+\\{\\{(.*)\\}\\}")
  private let diagnosticOffsetRegex =
      try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*@(-|\\+)(\\d+)\\s+\\{\\{(.*)\\}\\}")
  // swiftlint:enable force_try

  private let sourceContext: SourceContext

  public init(_ sourceContext: SourceContext) {
    self.sourceContext = sourceContext
  }

  public func verify(producedDiagnostics: [Diagnostic]) throws -> Bool {
    var success = true

    for file in sourceContext.sourceFiles {
      let sourceCode = try sourceContext.sourceCode(in: file)
      let diagnostics = producedDiagnostics.filter { $0.sourceLocation == nil || $0.sourceLocation?.file == file }
      success = try (success && verify(producedDiagnostics: diagnostics, sourceFile: file, sourceCode: sourceCode))
    }

    return success
  }

  public func verify(producedDiagnostics: [Diagnostic], sourceFile: URL, sourceCode: String) throws -> Bool {
    let expectations = parseExpectations(sourceCode: sourceCode)
    var producedDiagnostics = flatten(producedDiagnostics)
    var verifyDiagnostics = [Diagnostic]()

    for expectation in expectations {
      let index = producedDiagnostics.firstIndex(where: { diagnostic in
        let equalLineLocation: Bool
        if let sourceLocation = diagnostic.sourceLocation {
          equalLineLocation = sourceLocation.line == expectation.line
        } else {
          // 0 line locations do not exist - specifying 0 matches diagnostics with nil sourceLocation.
          equalLineLocation = expectation.line == 0
        }

        return diagnostic.message == expectation.message &&
        diagnostic.severity == expectation.severity &&
        equalLineLocation
      })

      if let index = index {
        producedDiagnostics.remove(at: index)
      } else {
        let sourceLocation: SourceLocation?
        if expectation.line == 0 {
          sourceLocation = nil
        } else {
          sourceLocation = SourceLocation(line: expectation.line, column: 0, length: 0, file: sourceFile)
        }

        let diagnostic =
            Diagnostic(severity: .error,
                       sourceLocation: sourceLocation,
                       message: "Verify: Should have produced \(expectation.severity) \"\(expectation.message)\"")
        verifyDiagnostics.append(diagnostic)
      }
    }

    for producedDiagnostic in producedDiagnostics where producedDiagnostic.severity != .note {
      let diagnostic =
          Diagnostic(severity: .error,
                     sourceLocation: producedDiagnostic.sourceLocation,
                     message: "Verify: Unexpected \(producedDiagnostic.severity) \"\(producedDiagnostic.message)\"")
      verifyDiagnostics.append(diagnostic)
    }

    let output = try DiagnosticsFormatter(diagnostics: verifyDiagnostics, sourceContext: sourceContext).rendered()
    if !output.isEmpty {
      print(output)
    }

    return verifyDiagnostics.isEmpty
  }

  func flatten(_ diagnostics: [Diagnostic]) -> [Diagnostic] {
    var allDiagnostics = diagnostics

    for diagnostic in diagnostics {
      allDiagnostics += flatten(diagnostic.notes)
    }

    return allDiagnostics
  }

  func parseExpectations(sourceCode: String) -> [Expectation] {
    let lines = sourceCode.components(separatedBy: "\n")
    return lines.enumerated().compactMap { index, line in
      return parseExpectation(sourceLine: line, line: index + 1)
    }
  }

  func parseExpectation(sourceLine: String, line: Int) -> Expectation? {
    let range = NSRange(sourceLine.startIndex..., in: sourceLine)
    if let match = diagnosticRegex.matches(in: sourceLine, range: range).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let messageRange = Range(match.range(at: 2), in: sourceLine)!
      let message = String(sourceLine[messageRange])

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    }

    if let match = diagnosticLineRegex.matches(in: sourceLine, range: range).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let lineRange = Range(match.range(at: 2), in: sourceLine)!
      let line = Int(sourceLine[lineRange])!

      let messageRange = Range(match.range(at: 3), in: sourceLine)!
      let message = String(sourceLine[messageRange])

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    }

    if let match = diagnosticOffsetRegex.matches(in: sourceLine, range: range).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let biasRange = Range(match.range(at: 2), in: sourceLine)
      let biasString = String(sourceLine[biasRange!])
      let biasFunc: (Int, Int) -> Int = biasString == "+" ? { $0 + $1 } : { $0 - $1 }

      let expectedLineRange = Range(match.range(at: 3), in: sourceLine)!
      let expectedLine = Int(sourceLine[expectedLineRange])!

      let messageRange = Range(match.range(at: 4), in: sourceLine)!
      let message = String(sourceLine[messageRange])

      let line = biasFunc(line, expectedLine)

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    }

    return nil
  }
}

extension DiagnosticsVerifier {
  struct Expectation: Hashable {
    var severity: Diagnostic.Severity
    var message: String
    var line: Int

    /* var hashValue: Int {
      return message.hashValue ^ severity.hashValue
    } */

    func hash(into hasher: inout Hasher) {
      hasher.combine(message)
      hasher.combine(severity)
    }
  }
}
