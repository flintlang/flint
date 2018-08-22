//
//  Environment+MatchFunction.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//

extension Environment {
  /// The result of attempting to match a function call to its function declaration.
  ///
  /// - matchedFunction: A matching function declaration has been found.
  /// - matchedInitializer: A matching initializer declaration has been found
  /// - failure: The function declaration could not be found.
  public enum FunctionCallMatchResult {
    case matchedFunction(FunctionInformation)
    case matchedInitializer(SpecialInformation)
    case matchedFallback(SpecialInformation)
    case matchedGlobalFunction(FunctionInformation)
    case failure(candidates: [FunctionInformation])
  }

  /// Attempts to match a function call to its function declaration.
  ///
  /// - Parameters:
  ///   - functionCall: The function call for which to find its associated function declaration.
  ///   - enclosingType: The type in which the function should be declared.
  ///   - callerCapabilities: The caller capabilities associated with the function call.
  ///   - scopeContext: Contextual information about the scope in which the function call appears.
  /// - Returns: A `FunctionCallMatchResult`, either `success` or `failure`.
  public func matchFunctionCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier, typeStates: [TypeState], callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> FunctionCallMatchResult {
    var candidates = [FunctionInformation]()

    var match: FunctionCallMatchResult? = nil

    let argumentTypes = functionCall.arguments.map {
      type(of: $0, enclosingType: enclosingType, scopeContext: scopeContext)
    }

    // Check if it can be a regular function.
    if let functions = types[enclosingType]?.functions[functionCall.identifier.name] {
      for candidate in functions {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities),
          areTypeStatesCompatible(source: typeStates, target: candidate.typeStates) else {
            candidates.append(candidate)
            continue
        }

        match = .matchedFunction(candidate)
      }
    }

    // Check if it can be an initializer.
    if let initializers = types[functionCall.identifier.name]?.initializers {
      for candidate in initializers {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            // TODO: Add initializer candidates.
            continue
        }

        if match != nil {
          // This is an ambiguous call. There are too many matches.
          return .failure(candidates: [])
        }

        match = .matchedInitializer(candidate)
      }
    }

    // Check if it can be a fallback function.
    if let fallbacks = types[functionCall.identifier.name]?.fallbacks {
      for candidate in fallbacks {
        guard areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
          // TODO: Add fallback candidates.
          continue
        }

        if match != nil {
          // This is an ambiguous call. There are too many matches.
          return .failure(candidates: [])
        }

        match = .matchedFallback(candidate)
      }
    }

    // Check if it can be a global function.
    if let functions = types[Environment.globalFunctionStructName]?.functions[functionCall.identifier.name] {
      for candidate in functions {

        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(candidate)
            continue
        }

        match = .matchedGlobalFunction(candidate)
      }
    }

    return match ?? .failure(candidates: candidates)
  }

  /// Associates a function call to an event call. Events are declared as properties in the contract's declaration.
  public func matchEventCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    let property = types[enclosingType]?.properties[functionCall.identifier.name]
    guard property?.rawType.isEventType ?? false, functionCall.arguments.count == property?.typeGenericArguments.count else { return nil }
    return property
  }
}
