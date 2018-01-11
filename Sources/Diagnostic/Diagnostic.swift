//
//  Diagnostic.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

public struct Diagnostic {
  public enum Severity: String {
    case warning
    case error
  }

  public var severity: Severity
  public var sourceLocation: SourceLocation?
  public var message: String

  public var isError: Bool {
    return severity == .error
  }

  public init(severity: Severity, sourceLocation: SourceLocation?, message: String) {
    self.severity = severity
    self.sourceLocation = sourceLocation
    self.message = message
  }
}
