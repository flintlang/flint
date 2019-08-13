//
//  FunctionDeclaration.swift
//  flintc
//
//  Created by matteo on 13/08/2019.
//

import AST
import Lexer

extension AST.FunctionDeclaration {
  public func generateWrapper() -> FunctionDeclaration {
    var wrapperFunctionDeclaration = self
    wrapperFunctionDeclaration.body.removeAll()
    // Add address referring to this contract and extract the instance of the contract from it
    let firstParameter = Parameter.constructParameter(name: "_address_\(MoveSelf.selfName)",
      type: .basicType(.address),
      sourceLocation: wrapperFunctionDeclaration
        .signature
        .parameters[0]
        .sourceLocation)
    
    // Swap this parameter with contract address in wrapper function
    let selfParameter = self.signature.parameters[0]
    wrapperFunctionDeclaration.signature.parameters[0] = firstParameter
    
    let selfDeclaration = selfParameter.asVariableDeclaration
    let selfAssignment = BinaryExpression(lhs: .variableDeclaration(selfDeclaration),
                                          op: Token(kind: .punctuation(.equal),
                                                    sourceLocation: self.sourceLocation),
                                          rhs: .rawAssembly(
                                            "borrow_global<T>(\(firstParameter.identifier.name.mangled))",
                                            resultType: selfDeclaration.type.rawType))
    let selfAssignmentStmt: Statement = .expression(.binaryExpression(selfAssignment))
    wrapperFunctionDeclaration.body.append(selfAssignmentStmt)
    
    
    let args: [FunctionArgument] = self.signature.parameters.map { parameter in
      return FunctionArgument(.identifier(parameter.identifier))
    }
    let returnExpression: Expression = .functionCall(FunctionCall(identifier: self.identifier,
                                                                  arguments: args,
                                                                  closeBracketToken: self.closeBraceToken,
                                                                  isAttempted: false))
    let returnToken: Token = .init(kind: .return,
                                   sourceLocation: self.body.last!.sourceLocation)
    let returnStmt: Statement = .returnStatement(.init(returnToken: returnToken,
                                                       expression: returnExpression))
    wrapperFunctionDeclaration.body.append(returnStmt)
    return wrapperFunctionDeclaration
  }
}
