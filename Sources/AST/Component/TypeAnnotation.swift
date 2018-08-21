//
//  TypeAnnotation.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A type annotation for a variable.
public struct TypeAnnotation: SourceEntity {
  public var colonToken: Token

  public var type: Type

  public var sourceLocation: SourceLocation {
    return .spanning(colonToken, to: type)
  }

  public init(colonToken: Token, type: Type) {
    self.colonToken = colonToken
    self.type = type
  }
}
