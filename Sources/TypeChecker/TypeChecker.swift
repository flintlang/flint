//
//  TypeChecker.swift
//  TypeChecker
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic

/// The `ASTPass` performing type checking.
public class TypeChecker: ASTPass {
  public init() {}

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    contractBehaviorDeclaration.states.forEach { typeState in
      if environment.isStateDeclared(typeState.identifier,
                                     in: contractBehaviorDeclaration.contractIdentifier.name) || typeState.isAny {
        // Become has an identifier of a state declared in the contract
      } else {
        diagnostics.append(
          .invalidState(falseState: .identifier(typeState.identifier),
                        contract: contractBehaviorDeclaration.contractIdentifier.name))
      }
    }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    let hiddenType = enumDeclaration.type.rawType
    for enumCase in enumDeclaration.cases {
      if let hiddenValue = enumCase.hiddenValue {
        let valueType = environment.type(of: hiddenValue,
                                         enclosingType: passContext.enclosingTypeIdentifier?.name ?? "",
                                         scopeContext: ScopeContext() )
        if !hiddenType.isCompatible(with: valueType), ![hiddenType, valueType].contains(.errorType) {
          diagnostics.append(.incompatibleCaseValueType(actualType: valueType,
                                                        expectedType: hiddenType,
                                                        expression: hiddenValue))
        }
      }
    }

    return ASTPassResult(element: enumDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    if passContext.inFunctionOrInitializer {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
      passContext.functionDeclarationContext?.innerDeclarations += [variableDeclaration]
      passContext.specialDeclarationContext?.innerDeclarations += [variableDeclaration]
    }

    let environment = passContext.environment!

    if let assignedExpression = variableDeclaration.assignedExpression {
      // The variable declaration is a state property.

      let lhsType = variableDeclaration.type.rawType
      let rhsType: RawType?

      switch assignedExpression {
      case .arrayLiteral:
        rhsType = RawType.arrayType(.any)
      case .dictionaryLiteral:
        rhsType = RawType.dictionaryType(key: .any, value: .any)
      default:
        rhsType = environment.type(of: assignedExpression,
                                   enclosingType: passContext.enclosingTypeIdentifier!.name,
                                   scopeContext: ScopeContext())
      }

      if let rhsType = rhsType, !lhsType.isCompatible(with: rhsType), ![lhsType, rhsType].contains(.errorType) {
        diagnostics.append(.incompatibleAssignment(lhsType: lhsType, rhsType: rhsType, expression: assignedExpression))
      }
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: diagnostics, passContext: passContext)
  }
}
