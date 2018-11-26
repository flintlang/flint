//
//  IREventCall.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for an event call.
struct IREventCall {
  var eventCall: FunctionCall
  var eventDeclaration: EventDeclaration

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    let types = eventDeclaration.variableDeclarations.map { $0.type }

    var preambles = [String]()
    var stores = [String]()
    var memoryOffset = 0

    for (i, argument) in eventCall.arguments.enumerated() {
      let argument = IRExpression(expression: argument.expression).rendered(functionContext: functionContext)
      preambles.append(argument.preamble)
      stores.append("mstore(\(memoryOffset), \(argument.expression))")
      memoryOffset += functionContext.environment.size(of: types[i].rawType) * EVM.wordSize
    }

    let totalSize = types.reduce(0) { return $0 + functionContext.environment.size(of: $1.rawType) } * EVM.wordSize
    let typeList = types.map { type in
      return "\(CanonicalType(from: type.rawType)!.rawValue)"
      }.joined(separator: ",")

    let eventHash = "\(eventCall.identifier.name)(\(typeList))".sha3(.keccak256)
    let log = "log1(0, \(totalSize), 0x\(eventHash))"

    return ExpressionFragment(
      pre: preambles.joined(separator: "\n"),
      """
      \(stores.joined(separator: "\n"))
      \(log)
      """)
  }
}
