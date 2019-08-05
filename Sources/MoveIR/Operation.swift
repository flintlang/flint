//
// Created by matthewross on 01/08/19.
//

import Foundation

// TODO check MoveIR does/will implement overflowing et al. operators,
//   otherwise get rid of them here and implement them in the creation
//   of MoveIR code

public enum Operation: CustomStringConvertible {
  case add(MoveIR.Expression, MoveIR.Expression)
  case overflowingAdd(MoveIR.Expression, MoveIR.Expression)
  case subtract(MoveIR.Expression, MoveIR.Expression)
  case overflowingSubtract(MoveIR.Expression, MoveIR.Expression)
  case times(MoveIR.Expression, MoveIR.Expression)
  case overflowingTimes(MoveIR.Expression, MoveIR.Expression)
  case divide(MoveIR.Expression, MoveIR.Expression)
  case modulo(MoveIR.Expression, MoveIR.Expression)
  case greaterThan(MoveIR.Expression, MoveIR.Expression)
  case lessThan(MoveIR.Expression, MoveIR.Expression)
  case greaterThanOrEqual(MoveIR.Expression, MoveIR.Expression)
  case lessThanOrEqual(MoveIR.Expression, MoveIR.Expression)
  case equal(MoveIR.Expression, MoveIR.Expression)
  case notEqual(MoveIR.Expression, MoveIR.Expression)
  case or(MoveIR.Expression, MoveIR.Expression)
  case and(MoveIR.Expression, MoveIR.Expression)
  case not(MoveIR.Expression)
  case power(MoveIR.Expression, MoveIR.Expression)
  case access(MoveIR.Expression, Identifier)

  public var description: String {
    switch self {
    case .add(let left, let right): return "\(left) + \(right)"
    case .overflowingAdd(let left, let right): return "\(left) + \(right)"
    case .subtract(let left, let right): return "\(left) - \(right)"
    case .overflowingSubtract(let left, let right): return  "\(left) - \(right)"
    case .times(let left, let right): return "\(left) * \(right)"
    case .overflowingTimes(let left, let right): return "\(left) * \(right)"
    case .divide(let left, let right): return "\(left) / \(right)"
    case .modulo(let left, let right): return "\(left) % \(right)"
    case .greaterThan(let left, let right): return "\(left) > \(right)"
    case .lessThan(let left, let right): return "\(left) < \(right)"
    case .greaterThanOrEqual(let left, let right): return "\(left) >= \(right)"
    case .lessThanOrEqual(let left, let right): return "\(left) <= \(right)"
    case .equal(let left, let right): return "\(left) == \(right)"
    case .notEqual(let left, let right): return "\(left) != \(right)"
    case .or(let left, let right): return "\(left) || \(right)"
    case .and(let left, let right): return "\(left) || \(right)"
    case .not(let expression): return "!\(expression)"
    case .power(let left, let right): return "\(left) ** \(right)"
    case .access(let object, let field): return "\(object).\(field)"
    }
  }
}
