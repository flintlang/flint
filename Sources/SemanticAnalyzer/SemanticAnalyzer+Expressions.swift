//
//  SemanticAnalyzer+Expression.swift
//  SemanticAnalyzer
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension SemanticAnalyzer {

  public func process(binaryExpression: BinaryExpression,
                      passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    switch binaryExpression.opToken {
    case .dot:
      let enclosingType = passContext.enclosingTypeIdentifier!
      let lhsType = environment.type(of: binaryExpression.lhs,
                                     enclosingType: enclosingType.name,
                                     scopeContext: passContext.scopeContext!)
      if case .identifier(let enumIdentifier) = binaryExpression.lhs,
        environment.isEnumDeclared(enumIdentifier.name) {
      } else if lhsType == .selfType, passContext.traitDeclarationContext == nil {
        diagnostics.append(.useOfSelfOutsideTrait(at: binaryExpression.lhs.sourceLocation))
      }
    case .equal:
      // Check if `call?` assignment
      if case .externalCall(let externalCall) = binaryExpression.rhs,
        externalCall.mode != .returnsGracefullyOptional,
        passContext.isInsideIfCondition {
        diagnostics.append(.ifLetConstructWithoutOptionalExternalCall(binaryExpression))
      }
    default:
      break
    }

    return ASTPassResult(element: binaryExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(typeConversionExpression: TypeConversionExpression,
                      passContext: ASTPassContext) -> ASTPassResult<TypeConversionExpression> {
    var diagnostics: [Diagnostic] = []
    if typeConversionExpression.kind != .cast {
      // Not implemented yet
      diagnostics.append(.notImplementedAs(typeConversionExpression))
    }

    guard let environment = passContext.environment,
      let enclosingType = passContext.enclosingTypeIdentifier,
      let scopeContext = passContext.scopeContext else {
        fatalError("No context available at callsite, unable to determine validity of as")
    }

    let expressionType = environment.type(of: typeConversionExpression.expression,
                                             enclosingType: enclosingType.name,
                                             scopeContext: scopeContext)

    // Check elementary casting constraint
    if expressionType.canReinterpret(as: typeConversionExpression.type.rawType) {
      // 1. If we have an external function call, we allow conversions between any kind of type
      // 2. If we have a solidity type conversion to a non-solidity type conversion we always allow it as the
      //    only place where we can get a Solidity type is from an external call
      if !passContext.isExternalFunctionCall && typeConversionExpression.type.rawType.isSolidityType {
        diagnostics.append(.badSolidityTypeConversion(typeConversionExpression, expressionType: expressionType))
      }
    } else {
      diagnostics.append(.typesNotReinterpretable(typeConversionExpression, expressionType: expressionType))
    }

    return ASTPassResult(element: typeConversionExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(attemptExpression: AttemptExpression,
                      passContext: ASTPassContext) -> ASTPassResult<AttemptExpression> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []

    if attemptExpression.isSoft,
      case .matchedFunction(let function) =
      environment.matchFunctionCall(attemptExpression.functionCall,
                                    enclosingType: passContext.enclosingTypeIdentifier!.name,
                                    typeStates: typeStates,
                                    callerProtections: [],
                                    scopeContext: ScopeContext()),
      !function.declaration.isVoid {
      diagnostics.append(.nonVoidAttemptCall(attemptExpression))
    }

    return ASTPassResult(element: attemptExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if environment.isInitializerCall(functionCall),
      !passContext.inAssignment,
      !passContext.isPropertyDefaultAssignment,
      functionCall.arguments.isEmpty {
      diagnostics.append(.noReceiverForStructInitializer(functionCall))
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(externalCall: ExternalCall, passContext: ASTPassContext) -> ASTPassResult<ExternalCall> {
    var parametersGiven: [String: Bool] = [
      "value": false,
      "gas": false
    ]
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    var passContext = passContext

    // ensure only one instance of value and gas hyper-parameters
    for parameter in externalCall.hyperParameters {
      if let identifier: Identifier = parameter.identifier {
        let name: String = identifier.name
        if let valueGiven: Bool = parametersGiven[name] {
          if valueGiven {
            diagnostics.append(.duplicateExternalCallHyperParameter(identifier))
          }
          parametersGiven[name] = true
        } else {
          diagnostics.append(.invalidExternalCallHyperParameter(identifier))
        }
      } else {
        diagnostics.append(.unlabeledExternalCallHyperParameter(externalCall))
      }
    }

    switch externalCall.mode {
    case .normal:
      // Ensure `call` is only used inside the do-body of do-catch statement
      if passContext.doCatchStatementStack.last != nil {
        // Update containsExternallCall value of doCatchStatement
        var doCatchStatementStack = passContext.doCatchStatementStack
        doCatchStatementStack[doCatchStatementStack.count - 1].containsExternalCall = true
        passContext = passContext.withUpdates {
          $0.doCatchStatementStack = doCatchStatementStack
        }
      } else {
        diagnostics.append(.normalExternalCallOutsideDoCatch(externalCall))
      }
    case .returnsGracefullyOptional:
      // Ensure 'call?' is only used in an 'if let ... = call? ...' construct
      if !passContext.isIfLetConstruct {
        diagnostics.append(.optionalExternalCallOutsideIfLet(externalCall))
      }
    case .isForced:
      // Ensure 'call!' is never used inside a do-catch block
      if passContext.doCatchStatementStack.count > 0 {
        diagnostics.append(.forcedExternalCallInsideDoCatch(externalCall))
      }
    }

    addMutatingExpression(.externalCall(externalCall), passContext: &passContext)

    // Ensure a return value is not ignored
    if environment.type(of: externalCall.functionCall.rhs,
                        enclosingType: enclosingType,
                        scopeContext: passContext.scopeContext!) != .basicType(.void) &&
      externalCall.mode != .returnsGracefullyOptional &&
      !passContext.inAssignment &&
      !passContext.isFunctionCallArgument {
      // TODO: disabled, broken (e.g. (call ...) == 0 is not ignoring the value)
      //diagnostics.append(.externalCallReturnValueIgnored(externalCall))
    }

    return ASTPassResult(element: externalCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(rangeExpression: AST.RangeExpression,
                      passContext: ASTPassContext) -> ASTPassResult<AST.RangeExpression> {
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
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []

    var diagnostics = [Diagnostic]()

    let isMutating: Bool =
      passContext.specialDeclarationContext?.declaration.isInit ?? false ||
        passContext.functionDeclarationContext?.isMutating ?? false

    if !passContext.isInEmit {
      // Find the function declaration associated with this function call.
      switch environment.matchFunctionCall(functionCall,
                                           enclosingType: functionCall.identifier.enclosingType ?? enclosingType,
                                           typeStates: typeStates,
                                           callerProtections: callerProtections,
                                           scopeContext: passContext.scopeContext!) {
      case .matchedFunction(let matchingFunction):
        // The function declaration is found.

        if matchingFunction.isMutating {
          // The function is mutating.
          addMutatingExpression(.functionCall(functionCall), passContext: &passContext)

          if !isMutating {
            // The function in which the function call appears in is not mutating.
            diagnostics.append(
              .useOfMutatingExpressionInNonMutatingFunction(
                .functionCall(functionCall),
                functionDeclaration: passContext.functionDeclarationContext!.declaration))
          }
        }

        if let externalCall = passContext.externalCallContext {

          // check value parameter (appropriate usage)
          if !matchingFunction.declaration.isPayable {
            if externalCall.hasHyperParameter(parameterName: "value") {
              diagnostics.append(.valueParameterForUnpayableFunction(externalCall))
            }
          } else {
            if !externalCall.hasHyperParameter(parameterName: "value") {
              diagnostics.append(.missingValueParameterForPayableFunction(externalCall))
            }
          }
        }

        checkArgumentLabels(functionCall, &diagnostics, isEventCall: false)
        checkFunctionArguments(functionCall, matchingFunction.declaration, &passContext, isMutating, &diagnostics)

      case .matchedInitializer(let matchingInitializer):
        checkFunctionArguments(functionCall,
                               matchingInitializer.declaration.asFunctionDeclaration,
                               &passContext,
                               isMutating,
                               &diagnostics)

      case .matchedFallback:
        break

      case .matchedGlobalFunction:
        break

      case .matchedFunctionWithoutCaller(let matchingFunctions):
        // The function declaration is found, but caller is incorrect
        if !functionCall.isAttempted || matchingFunctions.count > 1 {
          // If function call is not attempted, or there are multiple matching functions
          diagnostics.append(
            .noTryForFunctionCall(functionCall,
                                  contextCallerProtections: callerProtections,
                                  stateProtections: typeStates,
                                  candidates: matchingFunctions))
        }

      case .failure(let candidates):
        // A matching function declaration couldn't be found.
        diagnostics.append(.noMatchingFunctionForFunctionCall(functionCall, candidates: candidates))
      }
    } else if case .failure(let candidates) =
        environment.matchEventCall(functionCall,
                                   enclosingType: enclosingType,
                                   scopeContext: passContext.scopeContext ?? ScopeContext()) {
        // Event call has failed to match but has candidates
        if !candidates.isEmpty {
          diagnostics.append(.partialMatchingEvents(functionCall, candidates: candidates))
        } else {
          diagnostics.append(.noMatchingEvents(functionCall))
        }
    } else if case .matchedEvent(_) =
        environment.matchEventCall(functionCall,
                                   enclosingType: enclosingType,
                                   scopeContext: passContext.scopeContext ?? ScopeContext()) {
        checkArgumentLabels(functionCall, &diagnostics, isEventCall: true)
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  // Checks whether all arguments of a function call are labeled
  private func checkArgumentLabels(_ functionCall: FunctionCall,
                                   _ diagnostics: inout [Diagnostic],
                                   isEventCall: Bool) {

    if !functionCall.arguments.filter({$0.identifier == nil}).isEmpty {
      diagnostics.append(.unlabeledFunctionCallArguments(functionCall, isEventCall: isEventCall))
    }
  }

  /// Whether an expression refers to a state property.
  private func isStorageReference(expression: Expression, scopeContext: ScopeContext) -> Bool {
    switch expression {
    case .self: return true
    case .identifier(let identifier): return !scopeContext.containsDeclaration(for: identifier.name)
    case .inoutExpression(let inoutExpression):
      return isStorageReference(expression: inoutExpression.expression, scopeContext: scopeContext)
    case .binaryExpression(let binaryExpression):
      return isStorageReference(expression: binaryExpression.lhs, scopeContext: scopeContext)
    case .subscriptExpression(let subscriptExpression):
      return isStorageReference(expression: subscriptExpression.baseExpression, scopeContext: scopeContext)
    default: return false
    }
  }

  /// Checks whether the function arguments are storage references, and creates an error
  /// if the enclosing function is not mutating.
  fileprivate func checkFunctionArguments(_ functionCall: FunctionCall,
                                          _ declaration: (FunctionDeclaration),
                                          _ passContext: inout ASTPassContext,
                                          _ isMutating: Bool,
                                          _ diagnostics: inout [Diagnostic]) {
    // If there are arguments passed inout which refer to state properties, the enclosing
    // function need to be declared mutating.
    for (argument, parameter) in zip(functionCall.arguments, declaration.signature.parameters) where parameter.isInout {
      if isStorageReference(expression: argument.expression, scopeContext: passContext.scopeContext!) {
        addMutatingExpression(argument.expression, passContext: &passContext)

        if !isMutating {
          diagnostics.append(
            .useOfMutatingExpressionInNonMutatingFunction(
              .functionCall(functionCall),
              functionDeclaration: passContext.functionDeclarationContext!.declaration))
        }
      }
    }
  }
}
