//
//  IULIAWrapperFunction.swift
//  IRGen
//
//  Created by Hails, Daniel R on 19/07/2018.
//

import AST

struct IULIAWrapperFunction {
 static let prefixHard = "flintAttemptCallWrapperHard$"
 static let prefixSoft = "flintAttemptCallWrapperSoft$"
 let function: IULIAFunction

 func rendered(enclosingType: RawTypeIdentifier) -> String {
   return rendered(enclosingType: enclosingType, hard: true) + "\n" + rendered(enclosingType: enclosingType, hard: false)
 }

 func rendered(enclosingType: RawTypeIdentifier, hard: Bool) -> String {
   let callerCheck = IULIACallerCapabilityChecks.init(callerCapabilities: function.callerCapabilities, revert: false)
   let callerCode = callerCheck.rendered(enclosingType: enclosingType, environment: function.environment)
   let functionCall = function.signature(withReturn: false)

   let invalidCall = hard ? "revert(0, 0)" : "\(IULIAFunction.returnVariableName) := 0"

   var validCall = hard ? "\(IULIAFunction.returnVariableName) := \(functionCall)" : "\(functionCall)\n    \(IULIAFunction.returnVariableName) := 1"
   var returnSignature = "-> \(IULIAFunction.returnVariableName) "
   if hard, function.functionDeclaration.isVoid {
     validCall = functionCall
     returnSignature = ""
   }
   if !hard, !function.functionDeclaration.isVoid {
     validCall = "\(IULIAFunction.returnVariableName) := \(functionCall)\n    \(IULIAFunction.returnVariableName) := 1"
   }

   return """
   function \(signature(hard))\(returnSignature){
     \(callerCode.indented(by: 2))
     switch \(callerCheck.variableName)
     case 0 {
       \(invalidCall)
     }
     default {
       \(validCall)
     }
   }
   """
 }

 func signature(_ hard: Bool) -> String {
   return "\(hard ? IULIAWrapperFunction.prefixHard : IULIAWrapperFunction.prefixSoft)\(function.signature(withReturn: false))"
 }
}
