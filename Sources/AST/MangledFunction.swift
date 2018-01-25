//
//  MangledFunctionDeclaration.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct MangledFunction: CustomStringConvertible {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]

  public var functionDeclaration: FunctionDeclaration

  public var identifier: Identifier {
    return functionDeclaration.identifier
  }

  public var numParameters: Int {
    return functionDeclaration.parameters.count
  }

  public var isMutating: Bool {
    return functionDeclaration.isMutating
  }

  public var resultType: Type? {
    return functionDeclaration.resultType
  }

  public var rawType: Type.RawType {
    return functionDeclaration.rawType
  }

  init(functionDeclaration: FunctionDeclaration, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) {
    self.functionDeclaration = functionDeclaration
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
  }

  func canBeCalledBy(functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities callCallerCapabilities: [CallerCapability]) -> Bool {
    guard
      self.contractIdentifier == contractIdentifier,
      self.identifier == functionCall.identifier,
      self.numParameters == functionCall.arguments.count else {
        return false
    }

    for callCallerCapability in callCallerCapabilities {
      if !callerCapabilities.contains(where: { return callCallerCapability.isSubcapability(callerCapability: $0) }) {
        return false
      }
    }
    return true
  }

  func hasSameSignatureAs(_ functionCall: FunctionCall) -> Bool {
    return identifier == functionCall.identifier && numParameters == functionCall.arguments.count
  }

  public var description: String {
    let callerCapabilitiesDescription = "(\(callerCapabilities.map { $0.identifier.name }.joined(separator: ","))"
    return "\(identifier.name)_\(numParameters)_\(contractIdentifier.name)_\(callerCapabilitiesDescription)"
  }
}

extension MangledFunction: Hashable {
  public static func ==(lhs: MangledFunction, rhs: MangledFunction) -> Bool {
    return
      lhs.contractIdentifier == rhs.contractIdentifier &&
      lhs.callerCapabilities == rhs.callerCapabilities &&
      lhs.identifier == rhs.identifier &&
      lhs.numParameters == rhs.numParameters
  }

  public var hashValue: Int {
    return description.hashValue
  }
}
