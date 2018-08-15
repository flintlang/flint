//
//  SourceLocation.swift
//  AST
//
//  Created by Franklin Schrans on 1/7/18.
//

import Foundation

/// A location in a source file.
public struct SourceLocation: Comparable {

  public var line: Int
  public var column: Int
  public var length: Int
  public var file: URL
  public var isFromStdlib: Bool

  public init(line: Int, column: Int, length: Int, file: URL, isFromStdlib: Bool = false) {
    self.line = line
    self.column = column
    self.length = length
    self.file = file
    self.isFromStdlib = isFromStdlib
  }

  public static func spanning<S1: SourceEntity, S2: SourceEntity>(_ lowerBoundEntity: S1, to upperBoundEntity: S2) -> SourceLocation {
    let lowerBound = lowerBoundEntity.sourceLocation
    let upperBound = upperBoundEntity.sourceLocation
    guard lowerBound.line == upperBound.line else { return lowerBound }
    return SourceLocation(line: lowerBound.line, column: lowerBound.column, length: upperBound.column + upperBound.length - lowerBound.column, file: lowerBound.file)
  }

  public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return [lhs.line, lhs.column, lhs.length].lexicographicallyPrecedes([rhs.line, rhs.column, rhs.length])
  }
}
