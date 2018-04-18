//
//  Diagnostic.swift
//  Diagnostic
//
//  Created by Franklin Schrans on 1/4/18.
//

/// An error or warning encountered when compiling the source program.
public struct Diagnostic {

  /// The severity of the diagnostic.
  ///
  /// - warning: The compilation can continue, but it contains potentially dangerous code.
  /// - error: The compilation cannot continue, as it violates Flint's rules.
  /// - note: Additional information to display when a warning or error is produced.
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
