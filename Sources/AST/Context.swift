//
//  Context.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Context {
  public var declaredContractsIdentifiers = [Identifier]()
  public var functions = [MangledFunction]()
  public var contractVariablesMap = [Identifier: [VariableDeclaration]]()

  public func declaredCallerCapabilities(inContractWithIdentifier contractIdentifier: Identifier) -> [VariableDeclaration] {
    guard let variables = contractVariablesMap[contractIdentifier] else { return [] }
    return variables.filter { variable in
      guard case .builtInType(let builtInType) = variable.type.kind else {
        return false
      }

      return builtInType == .address
    }
  }

  public init() {}

  public func matchFunctionCall(_ functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> MangledFunction? {
    for function in functions {
      if function.canBeCalledBy(functionCall: functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities) {
        return function
      }
    }

    return nil
  }
}
