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
    if functionCall.identifier.name == "LibraCoin" {
      print("DEBUG")
    }
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

    // Remove the self argument if it's there
    var lookupCall = functionCall
    if let first: FunctionArgument = functionCall.arguments.first,
       case .`self` = first.expression {
       lookupCall.arguments.remove(at: 0)
    }

    /*if case .matchedInitializer(let initializer)
         = environment.matchFunctionCall(lookupCall, enclosingType: enclosingType,
                                         typeStates: [], callerProtections: [], scopeContext: scopeContext),
       initializer.declaration.generated {*/
    if environment.isExternalTraitInitializer(functionCall: lookupCall) {
      return MoveExpression(expression: lookupCall.arguments[0].expression, position: .normal)
        .rendered(functionContext: functionContext)
    }

    let args: [MoveIR.Expression] = functionCall.arguments.map({ (argument: FunctionArgument) in
      return MoveExpression(expression: argument.expression, position: .normal)
          .rendered(functionContext: functionContext)
    })

    // TODO please replace once module infrastructure has been implemented
    // It's okay because all function calls are on the local modules

    //let module = functionContext.environment.isTraitDeclared(functionCall.identifier.name) ?
    //functionCall.identifier.name : "Self."
    //let module = "Self"
    let identifier = functionCall.mangledIdentifier ?? functionCall.identifier.name
    return .functionCall(MoveIR.FunctionCall(identifier, args))
  }
}
