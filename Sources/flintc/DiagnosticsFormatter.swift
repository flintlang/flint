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
    return diagnostics.map({ renderDiagnostic($0) }).joined(separator: "\n")
  }

  func renderDiagnostic(_ diagnostic: Diagnostic, highlightColor: Color = .lightRed, style: Style = .bold) -> String {
    var sourceFileText = ""
    if let compilationContext = compilationContext {
      sourceFileText = " in \(compilationContext.fileName.bold)"
    }

    let infoTopic: String

    switch diagnostic.severity {
    case .error: infoTopic = "Error".lightRed.bold
    case .warning: infoTopic = "Warning".bold
    case .note: infoTopic = "Note".lightBlack.bold
    }

    let infoLine = "\(infoTopic)\(sourceFileText):"
    let body: String

    if let compilationContext = compilationContext {
      body = """
      \(diagnostic.message.indented(by: 2).bold)\(render(diagnostic.sourceLocation).bold):
      \(renderSourcePreview(at: diagnostic.sourceLocation, sourceCode: compilationContext.sourceCode, highlightColor: highlightColor, style: style))
      """
    } else {
      body = "  \(diagnostic.message.indented(by: 2).bold)"
    }

    let notes = diagnostic.notes.map({ renderDiagnostic($0, highlightColor: .white, style: .default) }).joined(separator: "\n")

    return """
    \(infoLine)
    \(body)\(notes.isEmpty ? "" : "\n  \(notes.indented(by: 2))")
    """
  }

  func render(_ sourceLocation: SourceLocation?) -> String {
    guard let sourceLocation = sourceLocation else { return "" }
    return " at line \(sourceLocation.line), column \(sourceLocation.column)"
  }

  func renderSourcePreview(at sourceLocation: SourceLocation?, sourceCode: String, highlightColor: Color, style: Style) -> String {
    let sourceLines = sourceCode.components(separatedBy: "\n")
    guard let sourceLocation = sourceLocation else { return "" }

    let spaceOffset = sourceLocation.column != 0 ? sourceLocation.column - 1 : 0

    let sourceLine = renderSourceLine(sourceLines[sourceLocation.line - 1], rangeOfInterest: (sourceLocation.column..<sourceLocation.column + sourceLocation.length), highlightColor: highlightColor, style: style)
    let indicator = String(repeating: " ", count: spaceOffset) + String(repeating: "^", count: sourceLocation.length).applyingCodes(highlightColor, style)

    return """
    \(sourceLine)
    \(indicator)
    """
  }

  func renderSourceLine(_ sourceLine: String, rangeOfInterest: Range<Int>, highlightColor: Color, style: Style) -> String {
    let lowerBound = rangeOfInterest.lowerBound != 0 ? rangeOfInterest.lowerBound - 1 : 0
    let upperBound = rangeOfInterest.upperBound != 0 ? rangeOfInterest.upperBound - 1 : sourceLine.count - 1

    let lowerBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: lowerBound)
    let upperBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: upperBound)

    return String(sourceLine[sourceLine.startIndex..<lowerBoundIndex]) + String(sourceLine[lowerBoundIndex..<upperBoundIndex]).applyingCodes(highlightColor, style) + String(sourceLine[upperBoundIndex..<sourceLine.endIndex])
  }
}

fileprivate extension String {
  func indented(by level: Int) -> String {
    let lines = components(separatedBy: "\n")
    return lines.joined(separator: "\n" + String(repeating: " ", count: level))
  }
}
