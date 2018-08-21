//
//  SourceEntity.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// An entity appearing in a source file.
public protocol SourceEntity: Equatable {
  var sourceLocation: SourceLocation { get }
}
