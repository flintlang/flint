//
 //  IULIACallerCapabilityChecks.swift
 //  IRGen
 //
 //  Created by Hails, Daniel R on 11/07/2018.
 //

 import AST

 /// Checks whether the caller of a function has appropriate caller capabilities.
 struct IULIACallerCapabilityChecks {
   static let postfix: String = "CallerCheck"
   static let varName: String = "_flint" + postfix

   var variableName: String
   var callerCapabilities: [CallerCapability]
   let revert: Bool

   init(callerCapabilities: [CallerCapability], revert: Bool = true, variableName: String = varName) {
     self.variableName = variableName
     self.callerCapabilities = callerCapabilities
     self.revert = revert
   }

   func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
     let checks = callerCapabilities.compactMap { callerCapability -> String? in
       guard !callerCapability.isAny else { return nil }

       let type = environment.type(of: callerCapability.identifier.name, enclosingType: enclosingType)
       let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: enclosingType)!

       switch type {
       case .fixedSizeArrayType(_, let size):
         return (0..<size).map { index in
           let check = IULIARuntimeFunction.isValidCallerCapability(address: "sload(add(\(offset), \(index)))")
           return "\(variableName) := add(\(variableName), \(check)"
           }.joined(separator: "\n")
       case .arrayType(_):
         let check = IULIARuntimeFunction.isCallerCapabilityInArray(arrayOffset: offset)
         return "\(variableName) := add(\(variableName), \(check))"
       default:
         let check = IULIARuntimeFunction.isValidCallerCapability(address: "sload(\(offset)))")
         return "\(variableName) := add(\(variableName), \(check)"
       }
     }
     let revertString = revert ? "if eq(\(variableName), 0) { revert(0, 0) }" : ""
     if !checks.isEmpty {
       return """
         let \(variableName) := 0
         \(checks.joined(separator: "\n"))
         \(revertString)
         """
     }

     return ""
   }
 }
