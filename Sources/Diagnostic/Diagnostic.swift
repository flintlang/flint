//
//  Diagnostic.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

public struct Diagnostic {
  public enum Severity {
    case warning
    case error
  }

  public var severity: Severity
  public var sourceRange: SourceRange
  public var message: String

  public init(severity: Severity, sourceRange: SourceRange, message: String) {
    self.severity = severity
    self.sourceRange = sourceRange
    self.message = message
  }
}

public struct SourceRange {
  public var line: Int
  public var column: Int
  public var length: Int

  public init(line: Int, column: Int, length: Int) {
    self.line = line
    self.column = column
    self.length = length
  }
}
