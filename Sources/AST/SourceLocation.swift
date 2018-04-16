//
//  SourceLocation.swift
//  AST
//
//  Created by Franklin Schrans on 1/7/18.
//

public struct SourceLocation: Equatable {
  public var line: Int
  public var column: Int
  public var length: Int

  public init(line: Int, column: Int, length: Int) {
    self.line = line
    self.column = column
    self.length = length
  }

  public static func spanning<S1: SourceEntity, S2: SourceEntity>(_ lowerBoundEntity: S1, to upperBoundEntity: S2) -> SourceLocation {
    let lowerBound = lowerBoundEntity.sourceLocation
    let upperBound = upperBoundEntity.sourceLocation
    guard lowerBound.line == upperBound.line else { return lowerBound }
    return SourceLocation(line: lowerBound.line, column: lowerBound.column, length: upperBound.column + upperBound.length - lowerBound.column)
  }
}
