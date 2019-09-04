//
//  FunctionDeclaration.swift
//  flintc
//
//  Created on 13/08/2019.
//

import AST
import Lexer
import Source

extension AST.FunctionDeclaration {
  public func generateContractWrapper(contractBehaviourDeclaration: ContractBehaviorDeclaration,
                                      passContext: ASTPassContext) -> FunctionDeclaration {
    var wrapperFunctionDeclaration = self
    wrapperFunctionDeclaration.mangledIdentifier = Mangler.mangleFunctionName(
        self.name,
        parameterTypes: Array(signature.parameters.dropFirst()).rawTypes,
        enclosingType: "",
        isContract: true
    )
    wrapperFunctionDeclaration.compilerTags += ["acquires T"]
    wrapperFunctionDeclaration.body.removeAll()

    if let returnVariableDeclarationStmt = body.first,
       !isVoid {
      wrapperFunctionDeclaration.body.append(returnVariableDeclarationStmt)
    }

    let firstParameter = Parameter.constructParameter(name: "_address_\(MoveSelf.name)",
      type: .basicType(.address),
      sourceLocation: wrapperFunctionDeclaration
        .signature
        .parameters[0]
        .sourceLocation)

    // Swap `this` parameter with contract address in wrapper function
    let selfParameter = self.signature.parameters[0]
    wrapperFunctionDeclaration.signature.parameters[0] = firstParameter

    let selfToken =  Token(kind: .`self`, sourceLocation: selfParameter.sourceLocation)
    let selfDeclaration = VariableDeclaration(modifiers: [],
                                              declarationToken: nil,
                                              identifier: Identifier(identifierToken: selfToken),
                                              type: selfParameter.type)
    wrapperFunctionDeclaration.body.append(.expression(.variableDeclaration(selfDeclaration)))
    let selfAssignment = BinaryExpression(lhs: .`self`(selfToken),
                                          op: Token(kind: .punctuation(.equal),
                                                    sourceLocation: self.sourceLocation),
                                          rhs: .rawAssembly(
                                            "borrow_global<T>(move(\(firstParameter.identifier.name.mangled)))",
                                            resultType: selfParameter.type.rawType))
    wrapperFunctionDeclaration.body.append(.expression(.binaryExpression(selfAssignment)))

    if !contractBehaviourDeclaration.callerProtections.contains(where: { $0.isAny }) {
      let callerBinding = Identifier(name: "_caller",
                                     sourceLocation: sourceLocation)
      wrapperFunctionDeclaration.body.insert(.expression(.variableDeclaration(
          VariableDeclaration(modifiers: [],
                              declarationToken: nil,
                              identifier: Identifier(name: Mangler.mangleName(callerBinding.name),
                                                     sourceLocation: sourceLocation),
                              type: Type(inferredType: .basicType(.address), identifier: callerBinding))
      )), at: 0)
      wrapperFunctionDeclaration.body.append(
          MovePreprocessor.generateCallerBindingStatement(callerBindingIdentifier: callerBinding)
      )

      let predicates = contractBehaviourDeclaration.callerProtections
          .map { (protection: CallerProtection) -> AST.Expression in
        var identifier = protection.identifier
        identifier.enclosingType = contractBehaviourDeclaration.contractIdentifier.name
        let type = passContext.environment!.type(of: .identifier(identifier),
                                                 enclosingType: contractBehaviourDeclaration.contractIdentifier.name,
                                                 scopeContext: ScopeContext())
        switch type {
        case .basicType(.address):
          return Expression.binaryExpression(BinaryExpression(
              lhs: .identifier(identifier),
              op: Token(kind: .punctuation(.doubleEqual), sourceLocation: protection.sourceLocation),
              rhs: .identifier(callerBinding)
          ))
        default: fatalError("Can currently only handle caller protection π(x) where x: Address")
        }
      }

      wrapperFunctionDeclaration.body.append(generateAssertion(
          predicates: predicates,
          functionContext: FunctionContext(environment: passContext.environment!,
                                           scopeContext: scopeContext!,
                                           enclosingTypeName: contractBehaviourDeclaration.contractIdentifier.name),
          error: sourceLocation.line
      ))
    }

    if !contractBehaviourDeclaration.states.contains(where: { $0.isAny }) {
      let typeStatePredicates = contractBehaviourDeclaration.states
          .map { (state: TypeState) -> Expression in
        let index = passContext.environment!.getStateValue(
            state.identifier,
            in: contractBehaviourDeclaration.contractIdentifier.name
        )
        return .binaryExpression(BinaryExpression(
            lhs: index,
            op: Token(kind: .punctuation(.doubleEqual), sourceLocation: state.sourceLocation),
            rhs: .identifier(Identifier(
                name: "\(MoveContract.stateVariablePrefix)\(contractBehaviourDeclaration.contractIdentifier.name)",
                sourceLocation: state.sourceLocation,
                enclosingType: contractBehaviourDeclaration.contractIdentifier.name
            ))
        ))
      }
      wrapperFunctionDeclaration.body.append(generateAssertion(
          predicates: typeStatePredicates,
          functionContext: FunctionContext(environment: passContext.environment!,
                                           scopeContext: scopeContext!,
                                           enclosingTypeName: contractBehaviourDeclaration.contractIdentifier.name),
          error: sourceLocation.line
      ))
    }

    let args: [FunctionArgument] = signature.parameters.map { parameter in
      FunctionArgument(.identifier(parameter.identifier))
    }

    let functionCallExpr: Expression = .functionCall(
      FunctionCall(identifier: Identifier(name: mangledIdentifier!,
                   sourceLocation: sourceLocation),
                   arguments: args,
                   closeBracketToken: closeBraceToken,
                   isAttempted: false))

    if isVoid {
      wrapperFunctionDeclaration.body.append(.expression(functionCallExpr))
    }

    wrapperFunctionDeclaration.body.append(.returnStatement(ReturnStatement(
        returnToken: Token(kind: .return,
                           sourceLocation: closeBraceToken.sourceLocation),
        expression: isVoid ? nil : functionCallExpr
    )))
    return wrapperFunctionDeclaration
  }

  private func generateAssertion(predicates: [AST.Expression],
                                 functionContext: FunctionContext,
                                 error: Int = 1) -> Statement {
    let predicate = predicates.reduce(nil) { (checks, check) -> Expression? in
      guard let checks = checks else {
        return check
      }
      return Expression.binaryExpression(BinaryExpression(
          lhs: checks,
          op: Token(kind: .punctuation(.or), sourceLocation: SourceLocation.DUMMY),
          rhs: check
      ))
    } ?? Expression.literal(Token(kind: .literal(.boolean(.true)), sourceLocation: SourceLocation.DUMMY))
    let predicateExpression = MoveExpression(expression: predicate).rendered(functionContext: functionContext)
    return .expression(.rawAssembly("""
                                    assert(\(predicateExpression), \(error))
                                    """,
                                    resultType: RawType.errorType))
  }
}
