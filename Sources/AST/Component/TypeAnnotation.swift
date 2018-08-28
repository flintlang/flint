//
//  TypeAnnotation.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A type annotation for a variable.
public struct TypeAnnotation: ASTNode {
  public var colonToken: Token

  public var type: Type

  public init(colonToken: Token, type: Type) {
    self.colonToken = colonToken
    self.type = type
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(colonToken)\(type)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(colonToken, to: type)
  }
}
