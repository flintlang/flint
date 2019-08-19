//
//  FunctionDeclaration.swift
//  flintc
//
//  Created on 13/08/2019.
//

import AST
import Lexer

extension AST.FunctionDeclaration {
  public func generateWrapper() -> FunctionDeclaration {
    var wrapperFunctionDeclaration = self
    wrapperFunctionDeclaration.mangledIdentifier = self.name
    wrapperFunctionDeclaration.body.removeAll()
    let returnVariableDeclarationStmt = self.body.first!
    let firstParameter = Parameter.constructParameter(name: "_address_\(MoveSelf.name)",
      type: .basicType(.address),
      sourceLocation: wrapperFunctionDeclaration
        .signature
        .parameters[0]
        .sourceLocation)

    // Swap `this` parameter with contract address in wrapper function
    let selfParameter = self.signature.parameters[0]
    wrapperFunctionDeclaration.signature.parameters[0] = firstParameter

    let selfToken: Token =  .init(kind: .`self`, sourceLocation: selfParameter.sourceLocation)
    let selfDeclaration: VariableDeclaration = .init(modifiers: [],
                                                     declarationToken: nil,
                                                     identifier: .init(identifierToken: selfToken),
                                                     type: selfParameter.type)
    let selfDeclarationStmt: Statement = .expression(.variableDeclaration(selfDeclaration))
    let selfAssignment = BinaryExpression(lhs: .`self`(selfToken),
                                          op: Token(kind: .punctuation(.equal),
                                                    sourceLocation: self.sourceLocation),
                                          rhs: .rawAssembly(
                                            "borrow_global<T>(move(\(firstParameter.identifier.name.mangled)))",
                                            resultType: selfParameter.type.rawType))
    let selfAssignmentStmt: Statement = .expression(.binaryExpression(selfAssignment))

    let args: [FunctionArgument] = self.signature.parameters.map { parameter in
      return FunctionArgument(.identifier(parameter.identifier))
    }
    let functionCallExpr: Expression = .functionCall(
      FunctionCall(identifier: .init(name: self.mangledIdentifier!,
                   sourceLocation: self.sourceLocation),
                   arguments: args,
                   closeBracketToken: self.closeBraceToken,
                   isAttempted: false))
    let returnToken: Token = .init(kind: .return,
                                   sourceLocation: self.body.last!.sourceLocation)

    let returnStmt: Statement = .returnStatement(.init(returnToken: returnToken,
                                                       expression: isVoid ? nil : functionCallExpr))
    wrapperFunctionDeclaration.body = self.isVoid
      ? [selfDeclarationStmt, selfAssignmentStmt, .expression(functionCallExpr), returnStmt]
      : [returnVariableDeclarationStmt, selfDeclarationStmt, selfAssignmentStmt, returnStmt]
    return wrapperFunctionDeclaration
  }
}
