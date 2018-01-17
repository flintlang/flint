//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST

public struct SemanticAnalyzer: ASTPass {
  public init() {}

  public func process(element: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()

    let context = passContext.context!

    if !context.declaredContractsIdentifiers.contains(element.contractIdentifier) {
      diagnostics.append(.contractBehaviorDeclarationNoMatchingContract(element))
    }

    let properties = context.properties(declaredIn: element.contractIdentifier)
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: element.contractIdentifier, contractProperties: properties, callerCapabilities: element.callerCapabilities)

    let passContext = passContext.withUpdates { $0.contractBehaviorDeclarationContext = declarationContext }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    let functionDeclarationContext = FunctionDeclarationContext(declaration: element, contractContext:  passContext.contractBehaviorDeclarationContext!)
    let passContext = passContext.withUpdates { $0.functionDeclarationContext = functionDeclarationContext }

    var diagnostics = [Diagnostic]()

    if element.isPayable {
      let payableValueParameters = element.parameters.filter { $0.isPayableValueParameter }
      if payableValueParameters.count > 1 {
        diagnostics.append(.ambiguousPayableValueParameter(element))
      } else if payableValueParameters.count == 0 {
        diagnostics.append(.payableFunctionDoesNotHavePayableValueParameter(element))
      }
    }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    if let functionDeclarationContext = passContext.functionDeclarationContext, element.isPropertyAccess {
      if !functionDeclarationContext.contractContext.isPropertyDeclared(element.name) {
        diagnostics.append(.useOfUndeclaredIdentifier(element))
        passContext.context!.addUsedUndefinedVariable(element, contractIdentifier: functionDeclarationContext.contractContext.contractIdentifier)
      }
      if let asLValue = passContext.asLValue, asLValue {
        if !functionDeclarationContext.isMutating {
          diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.identifier(element), functionDeclaration: functionDeclarationContext.declaration))
        }
        passContext.mutatingExpressions = [.identifier(element)]
      }
    }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
    let context = passContext.context!
    var diagnostics = [Diagnostic]()

    if !element.isAny && !context.containsCallerCapability(element, in: contractBehaviorDeclarationContext.contractIdentifier) {
      diagnostics.append(.undeclaredCallerCapability(element, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
    }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    if case .punctuation(.equal) = element.op.kind {
      passContext.asLValue = true
    }

    let functionDeclarationContext = passContext.functionDeclarationContext!

    if case .self(_) = element.lhs, passContext.asLValue!, !functionDeclarationContext.isMutating {
      diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.binaryExpression(element), functionDeclaration: functionDeclarationContext.declaration))
    }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    let functionDeclarationContext = passContext.functionDeclarationContext!
    let context = passContext.context!
    let contractIdentifier = functionDeclarationContext.contractContext.contractIdentifier
    var diagnostics = [Diagnostic]()

    if let matchingFunction = context.matchFunctionCall(element, contractIdentifier: functionDeclarationContext.contractContext.contractIdentifier, callerCapabilities: functionDeclarationContext.contractContext.callerCapabilities) {
      if matchingFunction.isMutating {
        if !functionDeclarationContext.isMutating {
          diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(element), functionDeclaration: functionDeclarationContext.declaration))
        }
      }
    } else if let _ = context.matchEventCall(element, contractIdentifier: contractIdentifier) {
    } else {
      diagnostics.append(.noMatchingFunctionForFunctionCall(element, contextCallerCapabilities: functionDeclarationContext.contractContext.callerCapabilities))
    }

    return ASTPassResult(element: element, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(element: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

}

extension ASTPassContext {
  var contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext? {
    get { return self[ContractBehaviorDeclarationContextEntry.self] }
    set { self[ContractBehaviorDeclarationContextEntry.self] = newValue }
  }

  var functionDeclarationContext: FunctionDeclarationContext? {
    get { return self[FunctionDeclarationContextEntry.self] }
    set { self[FunctionDeclarationContextEntry.self] = newValue }
  }

  var asLValue: Bool? {
    get { return self[AsLValueContextEntry.self] }
    set { self[AsLValueContextEntry.self] = newValue }
  }

  var mutatingExpressions: [Expression]? {
    get { return self[MutatingExpressionEntry.self] }
    set { self[MutatingExpressionEntry.self] = newValue }
  }
}

struct ContractBehaviorDeclarationContextEntry: PassContextEntry {
  typealias Value = ContractBehaviorDeclarationContext
}

struct FunctionDeclarationContextEntry: PassContextEntry {
  typealias Value = FunctionDeclarationContext
}

struct AsLValueContextEntry: PassContextEntry {
  typealias Value = Bool
}

struct MutatingExpressionEntry: PassContextEntry {
  typealias Value = [Expression]
}
