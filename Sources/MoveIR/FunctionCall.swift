//
//  FunctionCall.swift
//  YUL
//
//

public struct FunctionCall: CustomStringConvertible, Throwing {
  public let name: Identifier
  public let arguments: [Expression]

  public init(_ name: Identifier, _ arguments: [Expression]) {
    self.name = name
    self.arguments = arguments
  }

  public init(_ name: Identifier, _ arguments: Expression...) {
    self.init(name, arguments)
  }

  public var catchableSuccesses: [Expression] {
    return arguments.flatMap { argument in argument.catchableSuccesses }
  }

  public var description: String {
    let args = arguments.map({ arg in
      return arg.description
    }).joined(separator: ", ")
    return "\(name)(\(args))"
  }
}
