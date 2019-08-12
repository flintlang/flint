//
//  MoveFunctionCall.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a function call.
struct MoveFunctionCall {
  var functionCall: AST.FunctionCall

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let environment = functionContext.environment
    let enclosingType: RawTypeIdentifier = functionContext.enclosingTypeName
    let scopeContext: ScopeContext = functionContext.scopeContext

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: enclosingType,
                                 scopeContext: scopeContext) {
      return MoveEventCall(eventCall: functionCall, eventDeclaration: eventInformation.declaration)
        .rendered(functionContext: functionContext)
    }

    if case .matchedInitializer(let initializer) =
      environment.matchFunctionCall(functionCall, enclosingType: enclosingType,
                                    typeStates: [], callerProtections: [], scopeContext: scopeContext),
      initializer.declaration.generated {
      return MoveExpression(expression: functionCall.arguments[0].expression, position: .normal)
        .rendered(functionContext: functionContext)
    }

    let args: [MoveIR.Expression] = functionCall.arguments.map({ (argument: FunctionArgument) in
      return MoveExpression(expression: argument.expression, position: .normal)
          .rendered(functionContext: functionContext)
    })

    // TODO please replace once module infrastructure has been implemented
    // It's okay because all function calls are on the local modules
    let identifier = "Self.\(functionCall.mangledIdentifier ?? functionCall.identifier.name)"
    return .functionCall(MoveIR.FunctionCall(identifier, args))
  }

}
