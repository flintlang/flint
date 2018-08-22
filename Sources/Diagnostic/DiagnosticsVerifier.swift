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
  private let diagnosticRegex = try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*\\s+\\{\\{(.*)\\}\\}")
  private let diagnosticLineRegex = try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*@(\\d+)\\s+\\{\\{(.*)\\}\\}")
  private let diagnosticOffsetRegex = try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*@(-|\\+)(\\d+)\\s+\\{\\{(.*)\\}\\}")

  public init(){}

  public func verify(producedDiagnostics: [Diagnostic], compilationContext: CompilationContext) -> Bool {
    var success = true

    for file in compilationContext.sourceFiles {
      let sourceCode = compilationContext.sourceCode(in: file)
      let diagnostics = producedDiagnostics.filter { $0.sourceLocation == nil || $0.sourceLocation?.file == file }
      success = success && verify(producedDiagnostics: diagnostics, sourceFile: file, sourceCode: sourceCode, compilationContext: compilationContext)
    }

    return success
  }

  public func verify(producedDiagnostics: [Diagnostic], sourceFile: URL, sourceCode: String, compilationContext: CompilationContext) -> Bool {
    let expectations = parseExpectations(sourceCode: sourceCode)
    var producedDiagnostics = flatten(producedDiagnostics)
    var verifyDiagnostics = [Diagnostic]()

    for expectation in expectations {
      let index = producedDiagnostics.index(where: { diagnostic in
        let equalLineLocation: Bool
        if let sourceLocation = diagnostic.sourceLocation {
          equalLineLocation = sourceLocation.line == expectation.line
        } else {
          // 0 line locations do not exist - specifying 0 matches diagnostics with nil sourceLocation.
          equalLineLocation = expectation.line == 0
        }
        return diagnostic.message == expectation.message && diagnostic.severity == expectation.severity && equalLineLocation
      })

      if let index = index {
        producedDiagnostics.remove(at: index)
      } else {
        let sourceLocation = expectation.line == 0 ? nil : SourceLocation(line: expectation.line, column: 0, length: 0, file: sourceFile)
        verifyDiagnostics.append(Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Verify: Should have produced \(expectation.severity) \"\(expectation.message)\""))
      }
    }

    for producedDiagnostic in producedDiagnostics where producedDiagnostic.severity != .note {
      verifyDiagnostics.append(Diagnostic(severity: .error, sourceLocation: producedDiagnostic.sourceLocation, message: "Verify: Unexpected \(producedDiagnostic.severity) \"\(producedDiagnostic.message)\""))
    }

    let output = DiagnosticsFormatter(diagnostics: verifyDiagnostics, compilationContext: compilationContext).rendered()
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
    if let match = diagnosticRegex.matches(in: sourceLine, range: NSRange(sourceLine.startIndex..., in: sourceLine)).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let messageRange = Range(match.range(at: 2), in: sourceLine)!
      let message = String(sourceLine[messageRange])

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    } else if let match = diagnosticLineRegex.matches(in: sourceLine, range: NSRange(sourceLine.startIndex..., in: sourceLine)).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let lineRange = Range(match.range(at: 2), in: sourceLine)!
      let line = Int(sourceLine[lineRange])!

      let messageRange = Range(match.range(at: 3), in: sourceLine)!
      let message = String(sourceLine[messageRange])

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    } else if let match = diagnosticOffsetRegex.matches(in: sourceLine, range: NSRange(sourceLine.startIndex..., in: sourceLine)).first {
      let severityRange = Range(match.range(at: 1), in: sourceLine)!
      let severity = String(sourceLine[severityRange])

      let biasRange = Range(match.range(at: 2), in: sourceLine)
      let biasString = String(sourceLine[biasRange!])
      let biasFunc: (Int, Int) -> Int = biasString == "+" ? {$0 + $1} : {$0 - $1}

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

    var hashValue: Int {
      return message.hashValue ^ severity.hashValue
    }
  }
}
