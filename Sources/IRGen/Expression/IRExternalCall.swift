//
//  IRExternalCall.swift
//  IRGen
//
//  Created by Yicheng Luo on 11/14/18.
//
import AST

/// Generates code for a binary expression.
struct IRExternalCall {
  var externalCall: ExternalCall
  
  init(_ externalCall: ExternalCall) {
    self.externalCall = externalCall
  }
  
  func rendered(functionContext: FunctionContext) -> String {
    
    var elseCode = ""
    if let elseBlock = functionContext.top {
      elseCode = elseBlock.catchBody.map { statement in
        return IRStatement(statement: statement).rendered(functionContext: functionContext)
      }.joined(separator: "\n")
    } else {
      elseCode = ""
    }
    
    var code = """
    if (success of call) {
    
    } else {
      \(elseCode)
    }
    
    """
    
    return code
  }
}
