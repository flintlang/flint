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
      // Add address referring to this contract and extract the instance of the contract from it
      /*let contractAddressIdentifier = Identifier(
       identifierToken: Token(kind: .identifier("_address_\(MoveSelf.selfName)"),
       sourceLocation: functionDeclaration.sourceLocation)
       )
       let parameter = Parameter(identifier: contractAddressIdentifier,
       type: Type(inferredType: .basicType(.address), identifier: contractAddressIdentifier),
       implicitToken: nil,
       assignedExpression: nil)
       
       functionDeclaration.signature.parameters.insert(parameter, at: 0)
       
       let selfToken: Token = Token(kind: .`self`, sourceLocation: functionDeclaration.sourceLocation)
       let selfIdentifier = Identifier(identifierToken: selfToken)
       let selfType: RawType = .userDefinedType(contractBehaviorDeclarationContext.contractIdentifier.name)
       let selfDeclaration = VariableDeclaration(modifiers: [],
       declarationToken: nil,
       identifier: selfIdentifier,
       type: Type(inferredType: selfType, identifier: selfIdentifier))
       let selfAssignment = BinaryExpression(lhs: .variableDeclaration(selfDeclaration),
       op: Token(kind: .punctuation(.equal),
       sourceLocation: functionDeclaration.sourceLocation),
       rhs: .rawAssembly(
       "borrow_global<T>(\(contractAddressIdentifier.name.mangled))",
       resultType: selfType))
       let selfAssignmentStmt: Statement = .expression(.binaryExpression(selfAssignment))
       functionDeclaration.body.insert(selfAssignmentStmt, at: 0)*/
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
    }

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
