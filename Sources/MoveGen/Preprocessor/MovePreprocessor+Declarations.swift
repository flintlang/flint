//
//  MovePreprocessor+Declarations.swift
//
//  Created by matteo on 09/08/2019.
//

import AST
import Lexer

extension MovePreprocessor {
  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    if passContext.inFunctionOrInitializer {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
      passContext.functionDeclarationContext?.innerDeclarations += [variableDeclaration]
      passContext.specialDeclarationContext?.innerDeclarations += [variableDeclaration]
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration

    // Mangle the function name in the declaration.
    let parameters = functionDeclaration.signature.parameters.rawTypes
    let name = Mangler.mangleFunctionName(functionDeclaration.identifier.name,
                                          parameterTypes: parameters,
                                          enclosingType: passContext.enclosingTypeIdentifier!.name,
                                          isContract: passContext.contractBehaviorDeclarationContext != nil)
    functionDeclaration.mangledIdentifier = name

    // Bind the implicit Libra value of the transaction to a variable.
    if functionDeclaration.isPayable,
      let payableParameterIdentifier = functionDeclaration.firstPayableValueParameter?.identifier {
      let libraType = Identifier(identifierToken: Token(kind: .identifier("Libra"),
                                                        sourceLocation: payableParameterIdentifier.sourceLocation))
      let variableDeclaration = VariableDeclaration(modifiers: [],
                                                    declarationToken: nil,
                                                    identifier: payableParameterIdentifier,
                                                    type: Type(identifier: libraType))
      let closeBracketToken = Token(kind: .punctuation(.closeBracket),
                                    sourceLocation: payableParameterIdentifier.sourceLocation)
      let libra = FunctionCall(identifier: libraType,
                               arguments: [
                                FunctionArgument(identifier: nil,
                                                 expression: .literal(
                                                  Token(kind: .literal(.boolean(.true)),
                                                        sourceLocation: payableParameterIdentifier.sourceLocation
                                                 ))),
                                FunctionArgument(identifier: nil,
                                                 // FIXME Replace me
                                  expression: .rawAssembly(MoveRuntimeFunction.fatalError(),
                                                           resultType: .basicType(.int)))
        ],
                               closeBracketToken: closeBracketToken,
                               isAttempted: false)
      let equal = Token(kind: .punctuation(.equal), sourceLocation: payableParameterIdentifier.sourceLocation)
      let assignment: Expression = .binaryExpression(
        BinaryExpression(lhs: .variableDeclaration(variableDeclaration),
                         op: equal,
                         rhs: .functionCall(libra)))
      functionDeclaration.body.insert(.expression(assignment), at: 0)
    }

    if let structDeclarationContext = passContext.structDeclarationContext,
      Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
      // For struct functions, add `flintSelf` to the beginning of the parameters list.
      let parameter = constructThisParameter(
        type: .inoutType(.userDefinedType(structDeclarationContext.structIdentifier.name)),
        sourceLocation: functionDeclaration.sourceLocation)
      functionDeclaration.signature.parameters.insert(parameter, at: 0)
    } else if let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext,
      Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
      let parameter = constructThisParameter(
        type: .userDefinedType(contractBehaviorDeclarationContext.contractIdentifier.name),
        sourceLocation: functionDeclaration.sourceLocation)

      functionDeclaration.signature.parameters.insert(parameter, at: 0)

      if let callerBindingIdentifier = contractBehaviorDeclarationContext.callerBinding {
        functionDeclaration.body.insert(
          generateCallerBindingStatement(callerBindingIdentifier: callerBindingIdentifier),
          at: 0)
      }
    }

    functionDeclaration.scopeContext?.parameters = functionDeclaration.signature.parameters

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration
    functionDeclaration.body
      = getDeclarations(passContext: passContext) + deleteDeclarations(in: functionDeclaration.body)

    // Add trailing return statement to all functions if none is present
    if functionDeclaration.isVoid {
      if let last: Statement = functionDeclaration.body.last,
      case .returnStatement = last {} else {
        functionDeclaration.body.append(.returnStatement(ReturnStatement(
          returnToken: Token(kind: .return,
                             sourceLocation: functionDeclaration.closeBraceToken.sourceLocation),
          expression: nil
        )))
      }
    } else {
      // Add return variable
      let returnVariableDeclaration = VariableDeclaration(
        modifiers: [],
        declarationToken: nil,
        identifier: Identifier(name: MoveFunction.returnVariableName,
                               sourceLocation: functionDeclaration.body.last!.sourceLocation),
        type: functionDeclaration.signature.resultType!)
      functionDeclaration.body.insert(.expression(.variableDeclaration(returnVariableDeclaration)), at: 0)
    }
    //print(passContext.scopeContext!.localVariables)

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    if let callerBindingIdentifier = passContext.contractBehaviorDeclarationContext?.callerBinding {
      specialDeclaration.body.insert(
        generateCallerBindingStatement(callerBindingIdentifier: callerBindingIdentifier),
        at: 0)
    }
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    specialDeclaration.body
      = getDeclarations(passContext: passContext) + deleteDeclarations(in: specialDeclaration.body)
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  private func generateCallerBindingStatement(callerBindingIdentifier: Identifier) -> Statement {
    let addressType: RawType = .basicType(.address)
    let callerBindingAssignment = BinaryExpression(
      lhs: .identifier(callerBindingIdentifier),
      op: Token(kind: .punctuation(.equal),
                sourceLocation: callerBindingIdentifier.sourceLocation),
      rhs: .rawAssembly("get_txn_sender()", resultType: addressType))
    return .expression(.binaryExpression(callerBindingAssignment))
  }

  private func getDeclarations(passContext: ASTPassContext) -> [Statement] {
    let declarations = passContext.scopeContext!.localVariables.map { declaration -> Statement in
      var declaration: VariableDeclaration = declaration
      if !declaration.identifier.isSelf {
        declaration.identifier = Identifier(name: declaration.identifier.name.mangled,
                                            sourceLocation: declaration.identifier.sourceLocation)
      }
      return Statement.expression(.variableDeclaration(declaration))
    }
    return declarations
  }

  private func deleteDeclarations(in statements: [Statement]) -> [Statement] {
    return statements.compactMap { statement -> Statement? in
      switch statement {
      case .expression(let expression):
        if case .variableDeclaration(_) = expression {
          return nil
        }
      case .forStatement(var stmt):
        stmt.body = deleteDeclarations(in: stmt.body)
        return .forStatement(stmt)
      case .ifStatement(var stmt):
        stmt.body = deleteDeclarations(in: stmt.body)
        return .ifStatement(stmt)
      case .doCatchStatement(var stmt):
        stmt.catchBody = deleteDeclarations(in: stmt.catchBody)
        stmt.doBody = deleteDeclarations(in: stmt.doBody)
        return .doCatchStatement(stmt)
      default:
        return statement
      }
      return statement
    }
  }
}
