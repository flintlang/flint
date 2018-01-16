//
//  DiagnosticsFormatter.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

import Foundation
import Rainbow
import AST

public struct DiagnosticsFormatter {
  var diagnostics: [Diagnostic]
  var compilationContext: CompilationContext?

  public func rendered() -> String {
    let sourceFileText: String
    if let compilationContext = compilationContext {
      sourceFileText = " in \(compilationContext.fileName.bold)"
    } else {
      sourceFileText = ""
    }

    return diagnostics.map { diagnostic in
      let infoLine = "\(diagnostic.severity == .error ? "Error".lightRed.bold : "Warning")\(sourceFileText):"
      let body: String

      if let compilationContext = compilationContext {
        body = """
          \(diagnostic.message.indented(by: 2).bold)\(render(diagnostic.sourceLocation).bold):
          \(renderSourcePreview(at: diagnostic.sourceLocation, sourceCode: compilationContext.sourceCode).indented(by: 2))
        """
      } else {
        body = "  \(diagnostic.message.indented(by: 2).bold)"
      }

      return """
      \(infoLine)
      \(body)
      """
    }.joined(separator: "\n")
  }

  func render(_ sourceLocation: SourceLocation?) -> String {
    guard let sourceLocation = sourceLocation else { return "" }
    return " at line \(sourceLocation.line), column \(sourceLocation.column)"
  }

  func renderSourcePreview(at sourceLocation: SourceLocation?, sourceCode: String) -> String {
    let sourceLines = sourceCode.components(separatedBy: "\n")
    guard let sourceLocation = sourceLocation else { return "" }

    let spaceOffset = sourceLocation.column != 0 ? sourceLocation.column - 1 : 0
    return """
    \(renderSourceLine(sourceLines[sourceLocation.line - 1], rangeOfInterest: (sourceLocation.column..<sourceLocation.column + sourceLocation.length)))
    \(String(repeating: " ", count: spaceOffset) + String(repeating: "^", count: sourceLocation.length).lightRed.bold)
    """
  }

  func renderSourceLine(_ sourceLine: String, rangeOfInterest: Range<Int>) -> String {
    let lowerBound = rangeOfInterest.lowerBound != 0 ? rangeOfInterest.lowerBound - 1 : 0
    let upperBound = rangeOfInterest.upperBound != 0 ? rangeOfInterest.upperBound - 1 : sourceLine.count - 1

    let lowerBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: lowerBound)
    let upperBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: upperBound)

    return String(sourceLine[sourceLine.startIndex..<lowerBoundIndex]) + String(sourceLine[lowerBoundIndex..<upperBoundIndex]).red.bold + String(sourceLine[upperBoundIndex..<sourceLine.endIndex])
  }
}

fileprivate extension String {
  func indented(by level: Int) -> String {
    let lines = components(separatedBy: "\n")
    return lines.joined(separator: "\n" + String(repeating: " ", count: level))
  }
}
