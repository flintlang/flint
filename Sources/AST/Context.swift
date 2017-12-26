//
//  Context.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

import Foundation

public struct Context {
  public var functions = [MangledFunction]()

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
