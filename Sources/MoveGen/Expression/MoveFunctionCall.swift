//
//  MoveFunctionCall.swift
//  MoveGen
//
//
import AST
import MoveIR

/// Generates code for a function call.
struct MoveFunctionCall {
  var functionCall: AST.FunctionCall
  var moduleName: String

  public init(functionCall: AST.FunctionCall, moduleName: String = "Self") {
    self.functionCall = functionCall
    self.moduleName = moduleName
  }

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

    // Remove the self argument if it's there
    var lookupCall = functionCall
    if let first: FunctionArgument = functionCall.arguments.first,
       case .`self` = first.expression {
       lookupCall.arguments.remove(at: 0)
    }

    var moduleName = self.moduleName
    var callName = functionCall.mangledIdentifier ?? functionCall.identifier.name

    if environment.isExternalTraitInitializer(functionCall: lookupCall),
       let trait: TypeInformation = environment.types[lookupCall.identifier.name] {
      if trait.isExternalStruct {
        if trait.isExternalModule {
          moduleName = lookupCall.identifier.name
          callName = "new"
        }
      } else {
        let externalContractAddress = lookupCall.arguments[0].expression
        return MoveExpression(expression: externalContractAddress, position: .normal)
            .rendered(functionContext: functionContext)
      }
    }

    let args: [MoveIR.Expression] = functionCall.arguments.map({ (argument: FunctionArgument) in
      MoveExpression(expression: argument.expression, position: .normal)
          .rendered(functionContext: functionContext)
    })

    let identifier = "\(moduleName).\(callName)"
    return .functionCall(MoveIR.FunctionCall(identifier, args))
  }
}
