//
//  DiagnosticPool.swift
//  Diagnostic
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Source

public class DiagnosticPool {
  private var diagnostics: [Diagnostic]
  private let shouldVerify: Bool
  private let quiet: Bool
  private let sourceContext: SourceContext

  public var hasError: Bool {
    return diagnostics.contains(where: { $0.isError })
  }

  public init(shouldVerify: Bool, quiet: Bool, sourceContext: SourceContext) {
    self.diagnostics = []
    self.sourceContext = sourceContext
    self.quiet = quiet
    self.shouldVerify = shouldVerify
  }

  public func append(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }

  public func empty() {
    diagnostics = []
  }

  public func checkpoint(_ additions: [Diagnostic]) throws -> Bool? {
    diagnostics.append(contentsOf: additions)

    if hasError {
      if shouldVerify, try DiagnosticsVerifier(sourceContext).verify(producedDiagnostics: diagnostics) {
        return false
      } else if !shouldVerify {
        try display()
        return true
      } else {
        return true
      }
    }
    return nil
  }

  public func display() throws {
    var printableDiagnostics: [Diagnostic] = diagnostics
    if quiet {
      printableDiagnostics = diagnostics.filter({ $0.isError })
    }
    print(try DiagnosticsFormatter(diagnostics: printableDiagnostics, sourceContext: sourceContext).rendered())
  }
}
