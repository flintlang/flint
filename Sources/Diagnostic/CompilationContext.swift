//
//  CompilationContext.swift
//  Diagnostic
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Foundation

public struct CompilationContext {
  var sourceFiles: [URL]

  func sourceCode(in sourceFile: URL) -> String {
    return try! String(contentsOf: sourceFile)
  }

  public init(sourceFiles: [URL]){
    self.sourceFiles = sourceFiles
  }
}
