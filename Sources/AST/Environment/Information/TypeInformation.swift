//
//  TypeInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// A list of properties and functions declared in a type.
public struct TypeInformation {
  var orderedProperties = [String]()
  var properties = [String: PropertyInformation]()
  var functions = [String: [FunctionInformation]]()
  var events = [String: [EventInformation]]()
  var initializers = [SpecialInformation]()
  var fallbacks = [SpecialInformation]()
  var publicInitializer: SpecialDeclaration? = nil
  var publicFallback: SpecialDeclaration? = nil

  var conformances: [TypeInformation] = []

  public var allFunctions: [String: [FunctionInformation]] {
    return conformances.map({ $0.functions }).reduce(functions, +)
  }

  public var conformingFunctions: [FunctionInformation] {
    return conformances.flatMap({ $0.functions }).flatMap({ $0.value }).filter {
      !$0.isSignature
    }
  }

  public var allEvents: [String: [EventInformation]] {
    return conformances.map({ $0.events }).reduce(events, +)
  }

  public var allInitialisers: [SpecialInformation] {
    return initializers + conformances.flatMap({ $0.initializers })
  }
}

func + <K, V>(lhs: [K: [V]], rhs: [K: [V]]) -> [K: [V]] {
  var combined = lhs
  combined.merge(rhs, uniquingKeysWith: + )
  return combined
}
