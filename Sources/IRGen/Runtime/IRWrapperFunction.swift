//
//  IRWrapperFunction.swift
//  IRGen
//
//  Created by Hails, Daniel R on 19/07/2018.
//

import AST

struct IRWrapperFunction {
  static let prefixHard = "flintAttemptCallWrapperHard$"
  static let prefixSoft = "flintAttemptCallWrapperSoft$"
  let function: IRFunction

  func rendered(enclosingType: RawTypeIdentifier) -> String {
   return rendered(enclosingType: enclosingType, hard: true) +
    "\n" +
    rendered(enclosingType: enclosingType, hard: false)
  }

  func rendered(enclosingType: RawTypeIdentifier, hard: Bool) -> String {
    let callerCheck = IRCallerProtectionChecks.init(callerProtections: function.callerProtections, revert: false)
    let callerCode = callerCheck.rendered(enclosingType: enclosingType, environment: function.environment)
    let functionCall = function.signature(withReturn: false)

    let invalidCall = hard ? "revert(0, 0)" : "\(IRFunction.returnVariableName) := 0"

    var returnSignature = "-> \(IRFunction.returnVariableName) "

    let validCall: String
    if hard, function.functionDeclaration.isVoid {
      validCall = functionCall
      returnSignature = ""
    } else if !hard, !function.functionDeclaration.isVoid {
      validCall = "\(IRFunction.returnVariableName) := \(functionCall)\n    \(IRFunction.returnVariableName) := 1"
    } else if hard {
      validCall = "\(IRFunction.returnVariableName) := \(functionCall)"
    } else {
      validCall = "\(functionCall)\n    \(IRFunction.returnVariableName) := 1"
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
    let prefix = hard ? IRWrapperFunction.prefixHard : IRWrapperFunction.prefixSoft
    return "\(prefix)\(function.signature(withReturn: false))"
  }
}
