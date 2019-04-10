//
//  DiagnosticsFormatter.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

import Rainbow
import Source
import Utils

/// Formats error and warning messages.
public struct DiagnosticsFormatter {
  var diagnostics: [Diagnostic]
  var sourceContext: SourceContext?

  public init(diagnostics: [Diagnostic], sourceContext: SourceContext?) {
    self.diagnostics = diagnostics
    self.sourceContext = sourceContext
  }

  public func rendered() throws -> String {
    return try diagnostics.map({ try renderDiagnostic($0) }).joined(separator: "\n")
  }

  func renderDiagnostic(_ diagnostic: Diagnostic,
                        highlightColor: Color = .lightRed, style: Style = .bold) throws -> String {
    let diagnosticFile = diagnostic.sourceLocation?.file
    var sourceFileText = ""
    if let file = diagnosticFile {
      sourceFileText = " in \(file.path.bold)"
    }

    let infoTopic: String

    switch diagnostic.severity {
    case .error: infoTopic = "Error".lightRed.bold
    case .warning: infoTopic = "Warning".bold
    case .note: infoTopic = "Note".lightBlack.bold
    }

    let infoLine = "\(infoTopic)\(sourceFileText):"
    let body: String

    if let sourceContext = sourceContext, let file = diagnosticFile,
       let sourceCode = try? sourceContext.sourceCode(in: file) {
      let sourcePreview = renderSourcePreview(at: diagnostic.sourceLocation,
                                              sourceCode: sourceCode, highlightColor: highlightColor, style: style)
      body = """
      \(diagnostic.message.indented(by: 2).bold)\(render(diagnostic.sourceLocation).bold):
      \(sourcePreview)
      """
    } else {
      body = "  \(diagnostic.message.indented(by: 2).bold)"
    }

    let notes = try diagnostic.notes.map {
        try renderDiagnostic($0, highlightColor: .white, style: .default)
    }.joined(separator: "\n")

    return """
    \(infoLine)
    \(body)\(notes.isEmpty ? "" : "\n  \(notes.indented(by: 2))")
    """
  }

  func render(_ sourceLocation: SourceLocation?) -> String {
    guard let sourceLocation = sourceLocation else { return "" }
    return " at line \(sourceLocation.line), column \(sourceLocation.column)"
  }

  func renderSourcePreview(at sourceLocation: SourceLocation?,
                           sourceCode: String,
                           highlightColor: Color,
                           style: Style) -> String {
    let sourceLines = sourceCode.components(separatedBy: "\n")
    guard let sourceLocation = sourceLocation else { return "" }

    // TODO: rewrite this so that indentation is copied from the source line to the indicator, rather
    // than tabs being replaced by single spaces.
    let sourceLine = sourceLines[sourceLocation.line - 1].replacingOccurrences(of: "\t", with: " ")
    let spaceOffsetLength = sourceLocation.column != 0 ? sourceLocation.column - 1 : 0
    let spaceOffset = String(repeating: " ", count: spaceOffsetLength)

    let rangeOfInterest = sourceLocation.column..<sourceLocation.column + sourceLocation.length
    let renderedSourceLine = renderSourceLine(sourceLine, rangeOfInterest: rangeOfInterest,
                                              highlightColor: highlightColor, style: style)
    let indicator =
        spaceOffset + String(repeating: "^", count: sourceLocation.length).applyingCodes(highlightColor, style)

    return """
    \(renderedSourceLine)
    \(indicator)
    """
  }

  func renderSourceLine(_ sourceLine: String, rangeOfInterest: Range<Int>,
                        highlightColor: Color, style: Style) -> String {
    let lowerBound = rangeOfInterest.lowerBound != 0 ? rangeOfInterest.lowerBound - 1 : 0
    let upperBound = rangeOfInterest.upperBound != 0 ? rangeOfInterest.upperBound - 1 : max(0, sourceLine.count - 1)

    let lowerBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: lowerBound)
    let upperBoundIndex = sourceLine.index(sourceLine.startIndex, offsetBy: upperBound)

    return String(sourceLine[sourceLine.startIndex..<lowerBoundIndex]) +
        String(sourceLine[lowerBoundIndex..<upperBoundIndex]).applyingCodes(highlightColor, style) +
        String(sourceLine[upperBoundIndex..<sourceLine.endIndex])
  }
}
