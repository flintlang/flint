//
//  SemanticAnalyzer+Expression.swift
//  SemanticAnalyzer
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension SemanticAnalyzer {

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var binaryExpression = binaryExpression
    let environment = passContext.environment!

    if case .dot = binaryExpression.opToken {
      // The identifier explicitly refers to a state property, such as in `self.foo`.
      // We set its enclosing type to the type it is declared in.
      let enclosingType = passContext.enclosingTypeIdentifier!
      let lhsType = environment.type(of: binaryExpression.lhs, enclosingType: enclosingType.name, scopeContext: passContext.scopeContext!)
      if case .identifier(let enumIdentifier) = binaryExpression.lhs,
        environment.isEnumDeclared(enumIdentifier.name) {
        binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: enumIdentifier.name)
      } else {
        binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: lhsType.name)
      }
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if environment.isInitializerCall(functionCall),
      !passContext.inAssignment,
      !passContext.isPropertyDefaultAssignment,
      functionCall.arguments.isEmpty
    {
      diagnostics.append(.noReceiverForStructInitializer(functionCall))
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(rangeExpression: AST.RangeExpression, passContext: ASTPassContext) -> ASTPassResult<AST.RangeExpression> {
    var diagnostics = [Diagnostic]()

    if case .literal(let startToken) = rangeExpression.initial,
      case .literal(let endToken) = rangeExpression.bound {
      if startToken.kind == endToken.kind, rangeExpression.op.kind == .punctuation(.halfOpenRange) {
        diagnostics.append(.emptyRange(rangeExpression))
      }
    } else {
      diagnostics.append(.invalidRangeDeclaration(rangeExpression.initial))
    }

    return ASTPassResult(element: rangeExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    guard !Environment.isRuntimeFunctionCall(functionCall) else {
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    // Called once we've visited the function call's arguments.
    var passContext = passContext
    let environment = passContext.environment!
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerCapabilities = passContext.contractBehaviorDeclarationContext?.callerCapabilities ?? []
    let stateCapabilities = passContext.contractBehaviorDeclarationContext?.typeStates ?? []


    var diagnostics = [Diagnostic]()

    let isMutating = passContext.functionDeclarationContext?.isMutating ?? false

    // Find the function declaration associated with this function call.
    switch environment.matchFunctionCall(functionCall, enclosingType: functionCall.identifier.enclosingType ?? enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: passContext.scopeContext!) {
    case .matchedFunction(let matchingFunction):
      // The function declaration is found.

      if matchingFunction.isMutating {
        // The function is mutating.
        addMutatingExpression(.functionCall(functionCall), passContext: &passContext)

        if !isMutating {
          // The function in which the function call appears in is not mutating.
          diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: passContext.functionDeclarationContext!.declaration))
        }
      }
      checkFunctionArguments(functionCall, matchingFunction.declaration, &passContext, isMutating, &diagnostics)

    case .matchedInitializer(let matchingInitializer):
      checkFunctionArguments(functionCall, matchingInitializer.declaration.asFunctionDeclaration, &passContext, isMutating, &diagnostics)

    case .matchedFallback(_):
      break

    case .matchedGlobalFunction(_):
      break

    case .failure(let candidates):
      // A matching function declaration couldn't be found. Try to match an event call.
      if environment.matchEventCall(functionCall, enclosingType: enclosingType) == nil {
        diagnostics.append(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: callerCapabilities, stateCapabilities: stateCapabilities, candidates: candidates))
      }

    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  /// Whether an expression refers to a state property.
  private func isStorageReference(expression: Expression, scopeContext: ScopeContext) -> Bool {
    switch expression {
    case .self(_): return true
    case .identifier(let identifier): return !scopeContext.containsDeclaration(for: identifier.name)
    case .inoutExpression(let inoutExpression): return isStorageReference(expression: inoutExpression.expression, scopeContext: scopeContext)
    case .binaryExpression(let binaryExpression):
      return isStorageReference(expression: binaryExpression.lhs, scopeContext: scopeContext)
    case .subscriptExpression(let subscriptExpression):
      return isStorageReference(expression: subscriptExpression.baseExpression, scopeContext: scopeContext)
    default: return false
    }
  }

  /// Checks whether the function arguments are storage references, and creates an error if the enclosing function is not mutating.
  fileprivate func checkFunctionArguments(_ functionCall: FunctionCall, _ declaration: (FunctionDeclaration), _ passContext: inout ASTPassContext, _ isMutating: Bool, _ diagnostics: inout [Diagnostic]) {
    // If there are arguments passed inout which refer to state properties, the enclosing function need to be declared mutating.
    for (argument, parameter) in zip(functionCall.arguments, declaration.parameters) where parameter.isInout {
      if isStorageReference(expression: argument, scopeContext: passContext.scopeContext!) {
        addMutatingExpression(argument, passContext: &passContext)

        if !isMutating {
          diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: passContext.functionDeclarationContext!.declaration))
        }
      }
    }
  }
}
