//
//  MoveEventCall.swift
//  MoveGen
//
//
import AST
import MoveIR

/// Generates code for an event call.
struct MoveEventCall {
  var eventCall: AST.FunctionCall
  var eventDeclaration: EventDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let types = eventDeclaration.variableDeclarations.map { $0.type }

    var memoryOffset = 0

    for (i, argument) in eventCall.arguments.enumerated() {
      let argument = MoveExpression(expression: argument.expression).rendered(functionContext: functionContext)
      functionContext.emit(.expression(.functionCall(FunctionCall("mstore", .literal(.num(memoryOffset)), argument))))
      memoryOffset += functionContext.environment.size(of: types[i].rawType) * 1 /* EVM.wordSize */
    }

    let totalSize = types.reduce(0) { $0 + functionContext.environment.size(of: $1.rawType) } * 1 /* EVM.wordSize */
    let typeList = types.map { type in
      return "\(CanonicalType(from: type.rawType, environment: functionContext.environment)!)"
      }.joined(separator: ",")

    let eventHash = "\(eventCall.identifier.name)(\(typeList))".sha3(.keccak256)
    return MoveIR.Expression.functionCall(FunctionCall("log1", .literal(.num(0)),
                                                            .literal(.num(totalSize)),
                                                            .literal(.hex("0x\(eventHash)"))))
  }
}
