//
//  IRExternalCall.swift
//  IRGen
//
//  Created by Yicheng Luo on 11/14/18.
//
import AST

/// Generates code for an external call.
struct IRExternalCall {
  var externalCall: ExternalCall

  init(_ externalCall: ExternalCall) {
    self.externalCall = externalCall
  }

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    fatalError()
  }
}
