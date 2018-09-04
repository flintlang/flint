//
//  IRCallerCapabilityChecks.swift
//  IRGen
//
//  Created by Hails, Daniel R on 11/07/2018.
//

import AST

/// Checks whether the caller of a function has appropriate caller capabilities.
struct IRCallerCapabilityChecks {
  static let variableName = "_flintCallerCheck"

 var callerCapabilities: [CallerCapability]

 func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
   let checks = callerCapabilities.compactMap { callerCapability -> String? in
     guard !callerCapability.isAny else { return nil }

     let type = environment.type(of: callerCapability.identifier.name, enclosingType: enclosingType)
     let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: enclosingType)!

     switch type {
     case .fixedSizeArrayType(_, let size):
       return (0..<size).map { index in
         let check = IRRuntimeFunction.isValidCallerCapability(address: "sload(add(\(offset), \(index)))")
         return "\(IRCallerCapabilityChecks.variableName) := add(\(IRCallerCapabilityChecks.variableName), \(check)"
       }.joined(separator: "\n")
     case .arrayType(_):
       let check = IRRuntimeFunction.isCallerCapabilityInArray(arrayOffset: offset)
       return "\(IRCallerCapabilityChecks.variableName) := add(\(IRCallerCapabilityChecks.variableName), \(check))"
     case .dictionaryType(_, _):
       let check = IRRuntimeFunction.isCallerCapabilityInDictionary(dictionaryOffset: offset)
       return "\(IRCallerCapabilityChecks.variableName) := add(\(IRCallerCapabilityChecks.variableName), \(check))"
     default:
       let check = IRRuntimeFunction.isValidCallerCapability(address: "sload(\(offset))")
       return "\(IRCallerCapabilityChecks.variableName) := add(\(IRCallerCapabilityChecks.variableName), \(check))"
     }
   }

   if !checks.isEmpty {
     return """
       let \(IRCallerCapabilityChecks.variableName) := 0
       \(checks.joined(separator: "\n"))
       if eq(\(IRCallerCapabilityChecks.variableName), 0) { revert(0, 0) }
       """ + "\n"
   }

   return ""
 }
}
