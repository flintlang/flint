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
  /// - matchedFunctionsWithoutCaller: The matching function declarations without caller capabilities
  /// - matchedInitializer: A matching initializer declaration has been found
  /// - matchedFallback: A matching fallback declaration has been found
  /// - matchedGlobalFunction: A matching global function has been found
  /// - failure: The function declaration could not be found.
  public enum FunctionCallMatchResult {
    case matchedFunction(FunctionInformation)
    case matchedFunctionWithoutCaller([CallableInformation])
    case matchedInitializer(SpecialInformation)
    case matchedFallback(SpecialInformation)
    case matchedGlobalFunction(FunctionInformation)
    case failure(candidates: [CallableInformation])

    func merge(with match: FunctionCallMatchResult) -> FunctionCallMatchResult {
      if case .failure(let candidates1) = self {
        if case .failure(let candidates2) = match {
          return .failure(candidates: candidates1 + candidates2)
        }
        return match
      }
      return self
    }
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
    let match: FunctionCallMatchResult = .failure(candidates: [])

    let argumentTypes = functionCall.arguments.map {
      type(of: $0.expression, enclosingType: enclosingType, scopeContext: scopeContext)
    }

    // Check if it can be a regular function.
    let regularMatch = matchRegularFunction(functionCall: functionCall, enclosingType: enclosingType, argumentTypes: argumentTypes, typeStates: typeStates, callerCapabilities: callerCapabilities)

    // Check if it can be an initializer.
    let initaliserMatch = matchInitaliserFunction(functionCall: functionCall, argumentTypes: argumentTypes, callerCapabilities: callerCapabilities)

    // Check if it can be a fallback function.
    let fallbackMatch = matchFallbackFunction(functionCall: functionCall, callerCapabilities: callerCapabilities)

    // Check if it can be a global function.
    let globalMatch = matchGlobalFunction(functionCall: functionCall, argumentTypes: argumentTypes, callerCapabilities: callerCapabilities)

    return match.merge(with: globalMatch)
                .merge(with: fallbackMatch)
                .merge(with: initaliserMatch)
                .merge(with: regularMatch)
  }

  private func matchRegularFunction(functionCall: FunctionCall, enclosingType: RawTypeIdentifier, argumentTypes: [RawType], typeStates: [TypeState], callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [CallableInformation]()

    if let functions = types[enclosingType]?.allFunctions[functionCall.identifier.name] {
      for candidate in functions {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities),
          areTypeStatesCompatible(source: typeStates, target: candidate.typeStates) else {
            candidates.append(.functionInformation(candidate))
            continue
        }

        return .matchedFunction(candidate)
      }
      let matchedCandidates = candidates.filter{ $0.parameterTypes == argumentTypes }
      if matchedCandidates.count > 0 {
       return .matchedFunctionWithoutCaller(matchedCandidates)
      }

    }
    return .failure(candidates: candidates)
  }

  private func matchInitaliserFunction(functionCall: FunctionCall, argumentTypes: [RawType], callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [CallableInformation]()

    if let initializers = types[functionCall.identifier.name]?.allInitialisers {
      for candidate in initializers {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(.specialInformation(candidate))
            continue
        }

        return .matchedInitializer(candidate)
      }
    }
    return .failure(candidates: candidates)
  }

  private func matchFallbackFunction(functionCall: FunctionCall, callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [CallableInformation]()

    if let fallbacks = types[functionCall.identifier.name]?.fallbacks {
      for candidate in fallbacks {
        guard areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
          candidates.append(.specialInformation(candidate))
          continue
        }

        return .matchedFallback(candidate)
      }
    }

    return .failure(candidates: candidates)
  }

  private func matchGlobalFunction(functionCall: FunctionCall, argumentTypes: [RawType], callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [CallableInformation]()

    if let functions = types[Environment.globalFunctionStructName]?.allFunctions[functionCall.identifier.name] {
      for candidate in functions {

        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(.functionInformation(candidate))
            continue
        }

        return .matchedGlobalFunction(candidate)
      }
    }
    return .failure(candidates: candidates)
  }
}
