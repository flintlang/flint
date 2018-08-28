//
//  IREnum.swift
//  IRGen
//
//  Created by Hails, Daniel J R on 31/07/2018.
//

import AST

/// Generates code for an enum.
public struct IREnum {
  var structDeclaration: StructDeclaration
  var environment: Environment

  // Enum declarations never reach IR - references are removed in IRPreprocessing
  func rendered() -> String {
    return ""
  }
}
