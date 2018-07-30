//
//  IULIAEnum.swift
//  IRGen
//
//  Created by Hails, Daniel J R on 31/07/2018.
//

import AST

/// Generates code for an enum.
public struct IULIAEnum {
  var structDeclaration: StructDeclaration
  var environment: Environment

  // Enum declarations never reach IR - references are removed in IULIAPreprocessing
  func rendered() -> String {
    return ""
  }
}
