//
//  Diagnostic.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

public struct Diagnostic {
  public enum Severity: String {
    case warning
    case error
    case note
  }

  public var severity: Severity
  public var sourceLocation: SourceLocation?
  public var message: String

  public var notes: [Diagnostic]

  public var isError: Bool {
    return severity == .error
  }

  public init(severity: Severity, sourceLocation: SourceLocation?, message: String, notes: [Diagnostic] = []) {
    self.severity = severity
    self.sourceLocation = sourceLocation
    self.message = message
    self.notes = notes
  }
}
