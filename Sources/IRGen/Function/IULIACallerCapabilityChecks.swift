//
//  IULIACallerCapabilityChecks.swift
//  IRGen
//
//  Created by Franklin Schrans on 4/28/18.
//

import AST

/// Checks whether the caller of a function has appropriate caller capabilities.
struct IULIACallerCapabilityChecks {
  var callerCapabilities: [CallerCapability]

  func rendered(functionContext: FunctionContext) -> String {
    let environment = functionContext.environment

    let checks = callerCapabilities.compactMap { callerCapability -> String? in
      guard !callerCapability.isAny else { return nil }

      let type = environment.type(of: callerCapability.identifier.name, enclosingType: functionContext.enclosingTypeName)!
      let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: functionContext.enclosingTypeName)!
      switch type {
      case .fixedSizeArrayType(_, let size):
        return (0..<size).map { index in
          "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(add(\(offset), \(index)))))"
          }.joined(separator: "\n")
      case .arrayType(_):
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isCallerCapabilityInArray.rawValue)(\(offset)))"
      default:
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(\(offset))))"
      }
    }

    if !checks.isEmpty {
      return """
        let _flintCallerCheck := 0
        \(checks.joined(separator: "\n"))
        if eq(_flintCallerCheck, 0) { revert(0, 0) }
        """ + "\n"
    }

    return ""
  }
}
