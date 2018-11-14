//
//  TypeChecker+Statement.swift
//  TypeChecker
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension TypeChecker {
  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var diagnostics = [Diagnostic]()
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let functionDeclarationContext = passContext.functionDeclarationContext!
    let environment = passContext.environment!

    if let expression = returnStatement.expression {
      let actualType = environment.type(of: expression,
                                        enclosingType: typeIdentifier.name,
                                        scopeContext: passContext.scopeContext!)
      let expectedType = functionDeclarationContext.declaration.signature.rawType

      // Ensure the type of the returned value in a function matches the function's return type.

      if actualType != expectedType {
        diagnostics.append(.incompatibleReturnType(actualType: actualType,
                                                   expectedType: expectedType,
                                                   expression: expression))
      }
    }

    return ASTPassResult(element: returnStatement, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var diagnostics = [Diagnostic]()
    let contractIdentifier = passContext.enclosingTypeIdentifier!
    let environment = passContext.environment!

    if case .identifier(let identifier) = becomeStatement.expression,
      environment.isStateDeclared(identifier, in: contractIdentifier.name) {
      // Become has an identifier of a state declared in the contract
    } else {
      diagnostics.append(.invalidState(falseState: becomeStatement.expression, contract: contractIdentifier.name))
    }

    return ASTPassResult(element: becomeStatement, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    var diagnostics = [Diagnostic]()
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let environment = passContext.environment!

    let varType = environment.type(of: .variableDeclaration(forStatement.variable),
                                   enclosingType: typeIdentifier.name,
                                   scopeContext: passContext.scopeContext!)
    let iterableType = environment.type(of: forStatement.iterable,
                                        enclosingType: typeIdentifier.name,
                                        scopeContext: passContext.scopeContext!)

    let valueType: RawType
    switch iterableType {
    case .arrayType(let v): valueType = v
    case .rangeType(let v): valueType = v
    case .fixedSizeArrayType(let v, _): valueType = v
    case .dictionaryType(_, let v): valueType = v
    default:
      diagnostics.append(.incompatibleForIterableType(iterableType: iterableType,
                                                      statement: .forStatement(forStatement)))
      valueType = .errorType
    }

    if case .range(_) = forStatement.iterable, valueType != .basicType(.int) {
      diagnostics.append(.incompatibleForIterableType(iterableType: iterableType,
                                                      statement: .forStatement(forStatement)))
    }

    if !varType.isCompatible(with: valueType), ![varType, valueType].contains(.errorType) {
      diagnostics.append(.incompatibleForVariableType(varType: varType,
                                                      valueType: valueType,
                                                      statement: .forStatement(forStatement)))
    }

    return ASTPassResult(element: forStatement, diagnostics: diagnostics, passContext: passContext)
  }
}
