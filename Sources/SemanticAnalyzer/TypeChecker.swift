//
//  TypeChecker.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST

/// The `ASTPass` performing type checking.
public struct TypeChecker: ASTPass {
  public init() {}

  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    if let _ = passContext.functionDeclarationContext {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
    }

    let environment = passContext.environment!

    if let assignedExpression = variableDeclaration.assignedExpression {
      // The variable declaration is a state property.

      let lhsType = variableDeclaration.type.rawType
      let rhsType: Type.RawType?

      switch assignedExpression {
      case .literal(let literalToken):
        rhsType = environment.type(ofLiteralToken: literalToken)
      case .arrayLiteral(_):
        rhsType = Type.RawType.arrayType(.any)
      case .dictionaryLiteral(_):
        rhsType = Type.RawType.dictionaryType(key: .any, value: .any)
      default:
        rhsType = nil
      }

      if let rhsType = rhsType, !lhsType.isCompatible(with: rhsType), ![lhsType, rhsType].contains(.errorType) {
        diagnostics.append(.incompatibleAssignment(lhsType: lhsType, rhsType: rhsType, expression: assignedExpression))
      }
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  
  public func process(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    return ASTPassResult(element: initializerDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var diagnostics = [Diagnostic]()

    let environment = passContext.environment!

    // In an assignment, ensure the LHS and RHS have the same type.
    if case .punctuation(.equal) = binaryExpression.op.kind {
      let typeIdentifier = enclosingTypeIdentifier(in: passContext)

      let lhsType = environment.type(of: binaryExpression.lhs, enclosingType: typeIdentifier.name, scopeContext: passContext.scopeContext!)
      let rhsType = environment.type(of: binaryExpression.rhs, enclosingType: typeIdentifier.name, scopeContext: passContext.scopeContext!)

      if lhsType != rhsType, ![lhsType, rhsType].contains(.errorType) {
        diagnostics.append(.incompatibleAssignment(lhsType: lhsType, rhsType: rhsType, expression: .binaryExpression(binaryExpression)))
      }
    }

    return ASTPassResult(element: binaryExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let enclosingType = enclosingTypeIdentifier(in: passContext).name

    if let eventCall = environment.matchEventCall(functionCall, enclosingType: enclosingType) {
      let expectedTypes = eventCall.typeGenericArguments

      // Ensure an event call's arguments match the expected types.

      for (i, argument) in functionCall.arguments.enumerated() {
        let argumentType = environment.type(of: argument, enclosingType: enclosingType, scopeContext: passContext.scopeContext!)
        let expectedType = expectedTypes[i]
        if argumentType != expectedType {
          diagnostics.append(.incompatibleArgumentType(actualType: argumentType, expectedType: expectedType, expression: argument))
        }
      }
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var diagnostics = [Diagnostic]()
    let typeIdentifier = enclosingTypeIdentifier(in: passContext)
    let functionDeclarationContext = passContext.functionDeclarationContext!
    let environment = passContext.environment!

    if let expression = returnStatement.expression {
      let actualType = environment.type(of: expression, enclosingType: typeIdentifier.name, scopeContext: passContext.scopeContext!)
      let expectedType = functionDeclarationContext.declaration.rawType

      // Ensure the type of the returned value in a function matches the function's return type.

      if actualType != expectedType {
        diagnostics.append(.incompatibleReturnType(actualType: actualType, expectedType: expectedType, expression: expression))
      }
    }

    return ASTPassResult(element: returnStatement, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  
  public func postProcess(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    return ASTPassResult(element: initializerDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  
  public func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }
}
