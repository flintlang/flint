//
// Created by matthewross on 29/08/19.
//

import Foundation
import AST
import Source
import Lexer

public struct MoveMultipleBorrowPreventer: ASTPass {

  public init() {}

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var functionCall = functionCall
    var passContext = passContext
    var referenced = [Identifier]()
    var receiverTrail = functionCall.receiverTrail ?? []

    if receiverTrail.isEmpty {
      receiverTrail = [.`self`(Token(kind: .`self`, sourceLocation: functionCall.sourceLocation))]
    }

    if let last: Expression = receiverTrail.last {
      if case .identifier(let identifier) = last {
        referenced.append(identifier)
      } else if case .`self`(let token) = last {
        referenced.append(Identifier(name: "self", sourceLocation: token.sourceLocation))
      }
    }

    functionCall.arguments = functionCall.arguments.map { (argument: FunctionArgument) in
      var argument = argument
      if duplicateReferences(argument.expression, passContext: passContext, referenced: &referenced) {
        argument.expression = preAssign(argument.expression, passContext: &passContext)
        if let declaration: VariableDeclaration = passContext.scopeContext?.localVariables.last {
          passContext.preStatements.append(.expression(.variableDeclaration(declaration)))
        }
      }
      return argument
    }
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression,
                      passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    guard binaryExpression.isComputation else {
      return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
    }
    var binaryExpression = binaryExpression
    var passContext = passContext
    var referenced = [Identifier]()

    duplicateReferences(binaryExpression.lhs, passContext: passContext, referenced: &referenced)

    if duplicateReferences(binaryExpression.rhs, passContext: passContext, referenced: &referenced) {
      binaryExpression.rhs = preAssign(binaryExpression.rhs, passContext: &passContext)
      if let declaration: VariableDeclaration = passContext.scopeContext?.localVariables.last {
        passContext.preStatements.append(.expression(.variableDeclaration(declaration)))
      }
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  func duplicateReferences(_ expression: Expression,
                           passContext: ASTPassContext,
                           referenced: inout [Identifier]) -> Bool {
    switch expression {
    case .identifier(let identifier):
      guard let type = passContext.environment?.type(of: expression,
                                                     enclosingType: passContext.enclosingTypeIdentifier!.name,
                                                     scopeContext: passContext.scopeContext!),
            case .inoutType(let rawType) = type,
            type != .errorType && rawType != .errorType else {
        return false
      }
      if referenced.contains(where: { $0.name == identifier.name }) {
        return true
      } else {
        referenced.append(identifier)
      }
      return false
    case .`self`(let token):
      if passContext.specialDeclarationContext != nil {
        return false // If in constructor
      }
      if referenced.contains(where: { $0.name == "self" }) {
        return true
      } else {
        referenced.append(Identifier(name: "self", sourceLocation: token.sourceLocation))
      }
      return false
    case .functionCall(let call):
      // Will only reach unqualified (self.) function call thanks to no right recursion on `x.y`
      return duplicateReferences(.`self`(Token(kind: .`self`, sourceLocation: call.sourceLocation)),
                                 passContext: passContext,
                                 referenced: &referenced)
    case .binaryExpression(let binary):
      if duplicateReferences(binary.lhs,
                             passContext: passContext,
                             referenced: &referenced) {
        return true
      }
      if case .dot = binary.opToken {} else {
        return duplicateReferences(binary.rhs,
                                   passContext: passContext,
                                   referenced: &referenced)
      }
      return duplicateReferences(binary.lhs,
                                 passContext: passContext,
                                 referenced: &referenced)
      || binary.opToken == .dot && duplicateReferences(binary.rhs,
                                                       passContext: passContext,
                                                       referenced: &referenced)
    case .range(let range):
      return duplicateReferences(range.initial,
                                 passContext: passContext,
                                 referenced: &referenced)
          || duplicateReferences(range.bound,
                                 passContext: passContext,
                                 referenced: &referenced)
    case .typeConversionExpression(let typeConversionExpression):
      return duplicateReferences(typeConversionExpression.expression,
                                 passContext: passContext,
                                 referenced: &referenced)
    case .subscriptExpression(let `subscript`):
      return duplicateReferences(`subscript`.baseExpression,
                                 passContext: passContext,
                                 referenced: &referenced)
          || duplicateReferences(`subscript`.indexExpression,
                                 passContext: passContext,
                                 referenced: &referenced)
    case .arrayLiteral(let array):
      return array.elements.contains(where: {
        duplicateReferences($0, passContext: passContext, referenced: &referenced)
      })
    case .sequence(let expressions):
      return expressions.contains(where: {
        duplicateReferences($0, passContext: passContext, referenced: &referenced)
      })
    case .inoutExpression(let inOut):
      return duplicateReferences(inOut.expression, passContext: passContext, referenced: &referenced)
    default: break
    }
    return false
  }
}
