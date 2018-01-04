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
  public var sourceLocation: SourceLocation
  public var message: String

  public init(severity: Severity, sourceLocation: SourceLocation, message: String) {
    self.severity = severity
    self.sourceLocation = sourceLocation
    self.message = message
  }
}

public struct SourceLocation {
  public var line: Int
  public var column: Int
  public var length: Int

  public init(line: Int, column: Int, length: Int) {
    self.line = line
    self.column = column
    self.length = length
  }
}
