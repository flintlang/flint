//
//  Context.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Context {
  public var contractDeclarations = [ContractDeclaration]()
  public var functions = [MangledFunction]()
  var contractPropertyMap = [Identifier: [VariableDeclaration]]()

  public var declaredContractsIdentifiers: [Identifier] {
    return contractDeclarations.map { $0.identifier }
  }


  public init() {}

  public func properties(declaredIn contract: Identifier) -> [VariableDeclaration] {
    let contractDeclaration = contractDeclarations.first { $0.identifier == contract }!
    return contractDeclaration.variableDeclarations
  }

  public func declaredCallerCapabilities(inContractWithIdentifier contractIdentifier: Identifier) -> [VariableDeclaration] {
    let contractDefinitionIdentifier = declaredContractsIdentifiers.first { $0.name == contractIdentifier.name }!
    guard let variables = contractPropertyMap[contractDefinitionIdentifier] else { return [] }
    return variables.filter { variable in
      guard case .builtInType(let builtInType) = variable.type.rawType else {
        return false
      }

      return builtInType == .address
    }
  }

  public func type(of identifier: Identifier, contractIdentifier: Identifier) -> Type {
    return contractPropertyMap[contractIdentifier]!.first(where: { $0.identifier == identifier })!.type
  }

  public mutating func addVariableDeclarations(_ variableDeclarations: [VariableDeclaration], for contractIdentifier: Identifier) {
    contractPropertyMap[contractIdentifier, default: []].append(contentsOf: variableDeclarations)
  }

  public func matchFunctionCall(_ functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> MangledFunction? {
    for function in functions {
      if function.canBeCalledBy(functionCall: functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities) {
        return function
      }
    }

    return nil
  }
}
