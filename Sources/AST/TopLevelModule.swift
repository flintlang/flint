//
//  TopLevelModule.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A Flint top-level module. Includes top-level declarations, such as contract, struct, and contract behavior
/// declarations.
public struct TopLevelModule: Equatable {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
  }
}
