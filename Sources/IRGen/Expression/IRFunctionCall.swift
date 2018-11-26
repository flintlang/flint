//
//  IRFunctionCall.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a function call.
struct IRFunctionCall {
  var functionCall: FunctionCall

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    let environment = functionContext.environment
    let enclosingType: RawTypeIdentifier = functionContext.enclosingTypeName
    let scopeContext: ScopeContext = functionContext.scopeContext

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: enclosingType,
                                 scopeContext: scopeContext) {
      return IREventCall(eventCall: functionCall, eventDeclaration: eventInformation.declaration)
        .rendered(functionContext: functionContext)
    }

    if case .matchedInitializer(let initializer) =
      environment.matchFunctionCall(functionCall, enclosingType: enclosingType,
                                    typeStates: [], callerProtections: [], scopeContext: scopeContext),
      initializer.declaration.generated {
      return IRExpression(expression: functionCall.arguments[0].expression, asLValue: false)
        .rendered(functionContext: functionContext)
    }

    let (preamble, args) : (String, [String]) = functionCall.arguments.reduce(("", []), { acc, argument in
      let e = IRExpression(expression: argument.expression, asLValue: false).rendered(functionContext: functionContext)
      return (acc.0 + "\n" + e.preamble, acc.1 + [e.expression])
    })

    let identifier = functionCall.mangledIdentifier ?? functionCall.identifier.name
    return ExpressionFragment(pre: preamble, "\(identifier)(\(args.joined(separator: ", ")))")
  }

}
