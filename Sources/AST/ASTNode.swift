//
//  ASTNode.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source

/// An node of the AST defined by a position in the source file.
public protocol ASTNode: SourceEntity, CustomStringConvertible {
  var sourceLocation: SourceLocation { get }
}
