//
//  DiagnosticPool.swift
//  Diagnostic
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Source

public class DiagnosticPool {
  private var diagnostics: [Diagnostic] = []
  private var checkpoints: [[Diagnostic]] = []

  private func append(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }

  public func retrieve() -> [Diagnostic] {
    let latest = diagnostics
    diagnostics = []
    return latest
  }

  public func checkPoint() {
    checkpoints.append(diagnostics)
  }

  public func restore() {
    let last = checkpoints.removeLast()
    diagnostics = last
  }
}
