//
//  MoveVariableDeclaration.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a variable declaration.
struct MoveVariableDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
//    let allocate = MoveRuntimeFunction.allocateMemory(
//      size: functionContext.environment.size(of: variableDeclaration.type.rawType) * EVM.wordSize)
    let typeIR: MoveIR.`Type`
    switch CanonicalType(from: variableDeclaration.type.rawType)! {
    case .address: typeIR = .address
    case .u64: typeIR = .u64
    case .bool: typeIR = .bool
    case .bytearray: typeIR = .bytearray
    case .`struct`(let name): typeIR = .`struct`(name: name)
    case .resource(let name): typeIR = .resource(name: name)
    }
    return .variableDeclaration(MoveIR.VariableDeclaration(
        // FIXME convert Expression (AST) to Expression (MoveIR)
        (variableDeclaration.identifier.name, typeIR),
        variableDeclaration.assignedExpression.map { expr in
          MoveExpression(expression: expr).rendered(functionContext: functionContext)
        }
    ))
  }
}
