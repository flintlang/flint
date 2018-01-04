//
//  DiagnosticsFormatter.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

import Foundation

public struct DiagnosticsFormatter {
  var diagnostics: [Diagnostic]
  var sourceLines: [String]
  var fileName: String

  public init(diagnostics: [Diagnostic], sourceCode: String, fileName: String) {
    self.diagnostics = diagnostics
    self.sourceLines = sourceCode.components(separatedBy: .newlines)
    self.fileName = fileName
  }

  public func rendered() -> String {
    return diagnostics.map { diagnostic in
      return """
      \(diagnostic.severity == .error ? "Error" : "Warning") in \(fileName):
        \(diagnostic.message.indented(by: 2))\(render(diagnostic.sourceLocation)):
        \(renderSourcePreview(at: diagnostic.sourceLocation).indented(by: 2))
      """
    }.joined(separator: "\n\n")
  }

  func render(_ sourceLocation: SourceLocation?) -> String {
    guard let sourceLocation = sourceLocation else { return "" }
    return " at line \(sourceLocation.line), column \(sourceLocation.column)"
  }

  func renderSourcePreview(at sourceLocation: SourceLocation?) -> String {
    guard let sourceLocation = sourceLocation else { return "" }
    return """
    \(sourceLines[sourceLocation.line - 1])
    \(String(repeating: " ", count: sourceLocation.column - 1) + String(repeating: "^", count: sourceLocation.length))

    """
  }
}

fileprivate extension String {
  func indented(by level: Int) -> String {
    let lines = components(separatedBy: "\n")
    return lines.joined(separator: "\n" + String(repeating: " ", count: level))
  }
}
