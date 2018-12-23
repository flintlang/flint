//
//  IREventCall.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL

/// Generates code for an event call.
struct IREventCall {
  var eventCall: AST.FunctionCall
  var eventDeclaration: EventDeclaration

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    let types = eventDeclaration.variableDeclarations.map { $0.type }

    var memoryOffset = 0

    for (i, argument) in eventCall.arguments.enumerated() {
      let argument = IRExpression(expression: argument.expression).rendered(functionContext: functionContext)
      functionContext.emit(.expression(.functionCall(FunctionCall("mstore", [.literal(.num(memoryOffset)), argument]))))
      memoryOffset += functionContext.environment.size(of: types[i].rawType) * EVM.wordSize
    }

    let totalSize = types.reduce(0) { return $0 + functionContext.environment.size(of: $1.rawType) } * EVM.wordSize
    let typeList = types.map { type in
      return "\(CanonicalType(from: type.rawType)!.rawValue)"
      }.joined(separator: ",")

    let eventHash = "\(eventCall.identifier.name)(\(typeList))".sha3(.keccak256)
    return YUL.Expression.functionCall(FunctionCall("log1", [.literal(.num(0)),
                                                             .literal(.num(totalSize)),
                                                             .literal(.hex("0x\(eventHash)"))]))
  }
}
