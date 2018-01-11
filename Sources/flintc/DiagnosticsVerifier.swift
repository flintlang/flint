//
//  DiagnosticsVerifier.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/11/18.
//

// This is inspired by https://github.com/silt-lang/silt/blob/master/Sources/Drill/DiagnosticVerifier.swift

import Foundation
import Diagnostic
import AST

struct DiagnosticsVerifier {
  private let diagnosticRegex = try! NSRegularExpression(pattern: "//\\s*expected-(error|note|warning)\\s*@(-?\\d+)\\s+\\{\\{(.*)\\}\\}")

  func verify(producedDiagnostics: [Diagnostic], compilationContext: CompilationContext) -> Bool {
    let expectations = parseExpectations(sourceCode: compilationContext.sourceCode)
    var producedDiagnostics = producedDiagnostics
    var verifyDiagnostics = [Diagnostic]()

    for expectation in expectations {
      let index = producedDiagnostics.index(where: { diagnostic in
        let equalLineLocation = diagnostic.sourceLocation?.line == expectation.line
        return diagnostic.message == expectation.message && diagnostic.severity == expectation.severity && equalLineLocation
      })

      if let index = index {
        producedDiagnostics.remove(at: index)
      } else {
        verifyDiagnostics.append(Diagnostic(severity: .error, sourceLocation: SourceLocation(line: expectation.line, column: 0, length: 0), message: "Verify: Should have produced \(expectation.severity) \"\(expectation.message)\""))
      }
    }

    for producedDiagnostic in producedDiagnostics {
      verifyDiagnostics.append(Diagnostic(severity: .error, sourceLocation: SourceLocation(line: producedDiagnostic.sourceLocation!.line, column: 0, length: 0), message: "Verify: Unexpected \(producedDiagnostic.severity) \"\(producedDiagnostic.message)\""))
    }

    let output = DiagnosticsFormatter(diagnostics: verifyDiagnostics, compilationContext: compilationContext).rendered()
    if !output.isEmpty {
      print(output)
    }

    return verifyDiagnostics.isEmpty
  }

  func parseExpectations(sourceCode: String) -> [Expectation] {
    let matches = diagnosticRegex.matches(in: sourceCode, range: NSRange(sourceCode.startIndex..., in: sourceCode))

    return matches.map { match -> Expectation in
      let severityRange = Range(match.range(at: 1), in: sourceCode)!
      let severity = String(sourceCode[severityRange])

      let lineRange = Range(match.range(at: 2), in: sourceCode)!
      let line = Int(sourceCode[lineRange])!

      let messageRange = Range(match.range(at: 3), in: sourceCode)!
      let message = String(sourceCode[messageRange])

      return Expectation(severity: Diagnostic.Severity(rawValue: severity)!, message: message, line: line)
    }
  }
}

extension DiagnosticsVerifier {
  struct Expectation: Hashable {
    var severity: Diagnostic.Severity
    var message: String
    var line: Int

    static func ==(lhs: DiagnosticsVerifier.Expectation, rhs: DiagnosticsVerifier.Expectation) -> Bool {
      return lhs.message == rhs.message && lhs.severity == rhs.severity
    }

    var hashValue: Int {
      return message.hashValue ^ severity.hashValue
    }
  }
}
