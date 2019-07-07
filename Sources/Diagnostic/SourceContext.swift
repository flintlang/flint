//
//  CompilationContext.swift
//  Diagnostic
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Foundation

public struct SourceContext {
  var sourceCodeString: String
  var sourceFiles: [URL]
  var isForServer: Bool

  func sourceCode(in sourceFile: URL) throws -> String {
    if isForServer
    {
        return sourceCodeString
    } else
    {
        return try String(contentsOf: sourceFile)
        
    }
  }

  public init(sourceFiles: [URL], sourceCodeString: String = "", isForServer : Bool = false) {
      self.sourceFiles = sourceFiles
      self.sourceCodeString = sourceCodeString
      self.isForServer = isForServer
  }
}
