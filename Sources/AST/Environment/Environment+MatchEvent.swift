//
//  Environment+MatchEvent.swift
//  AST
//
//  Created by Hails, Daniel R on 29/08/2018.
//

extension Environment {
  /// The result of attempting to match a function call to an event declaration.
  ///
  /// - matchedEvent: A matching event declaration has been found.
  /// - failure: The event declaration could not be found.
  public enum EventMatchResult {
    case matchedEvent(EventInformation)
    case failure(candidates: [EventInformation])
  }

  /// Associates a function call to an event call. Events are declared as properties in the contract's declaration.
  public func matchEventCall(_ functionCall: FunctionCall,
                             enclosingType: RawTypeIdentifier,
                             scopeContext: ScopeContext) -> EventMatchResult {
    var candidates = [EventInformation]()

    if let events = types[enclosingType]?.allEvents[functionCall.identifier.name] {
      for candidate in events {
        guard areArgumentsCompatible(source: functionCall.arguments,
                                     target: candidate,
                                     enclosingType: enclosingType,
                                     scopeContext: scopeContext) else {
            candidates.append(candidate)
            continue
        }

        return .matchedEvent(candidate)
      }
    }
    return .failure(candidates: candidates)
  }
}
