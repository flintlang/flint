//
//  CompilationContext.swift
//  Diagnostic
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Foundation

public struct SourceContext {
  var sourceFiles: [URL]

  func sourceCode(in sourceFile: URL) throws -> String {
    return try String(contentsOf: sourceFile)
  }

  public init(sourceFiles: [URL]) {
    self.sourceFiles = sourceFiles
  }
}
