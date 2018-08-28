//
//  SourceLocation.swift
//  Source
//
//  Created by Franklin Schrans on 1/7/18.
//

import Foundation

/// A location in a source file.
public struct SourceLocation: Comparable, CustomStringConvertible {

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

  // MARK: - CustomStringConvertible
  public var description: String { return "\(file.lastPathComponent)@\(line):\(column):\(length)"}

  // MARK: - Comparable
  public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return [lhs.line, lhs.column, lhs.length].lexicographicallyPrecedes([rhs.line, rhs.column, rhs.length])
  }
}

extension SourceLocation {
  public static let DUMMY = SourceLocation(line: 0, column: 0, length: 0, file: .init(fileURLWithPath: ""))
  public static let INVALID = SourceLocation(line: -1, column: -1, length: -1, file: .init(fileURLWithPath: ""))

  public var isValid: Bool {
    return line > 0 && column > 0 && length > 0 && file.path != ""
  }
}
