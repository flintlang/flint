//
//  MangledFunctionDeclaration.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct MangledFunction {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]

  public var identifier: Identifier
  public var numParameters: Int

  init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability], functionDeclaration: FunctionDeclaration) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
    self.identifier = functionDeclaration.identifier
    self.numParameters = functionDeclaration.parameters.count
  }

  func canBeCalledBy(functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities callCallerCapabilities: [CallerCapability]) -> Bool {
    guard
      self.contractIdentifier == contractIdentifier,
      self.identifier == functionCall.identifier,
      self.numParameters == functionCall.arguments.count else {
        return false
    }

    for callerCapability in callerCapabilities {
      if !callCallerCapabilities.contains(where: { return $0.isSubcapability(callerCapability: callerCapability) }) {
        return false
      }
    }
    return true
  }
}

extension MangledFunction: Equatable {
  public static func ==(lhs: MangledFunction, rhs: MangledFunction) -> Bool {
    return
      lhs.contractIdentifier == rhs.contractIdentifier &&
      lhs.callerCapabilities == rhs.callerCapabilities &&
      lhs.identifier == rhs.identifier &&
      lhs.numParameters == rhs.numParameters
  }
}
