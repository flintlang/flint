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

      let predicate = contractBehaviourDeclaration.callerProtections
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
      }.reduce (nil) { (checks, check) -> Expression? in
        guard let checks = checks else {
          return check
        }
        return Expression.binaryExpression(BinaryExpression(
            lhs: checks,
            op: Token(kind: .punctuation(.or), sourceLocation: callerBinding.sourceLocation),
            rhs: check
        ))
      }

      let predicateExpression = MoveExpression(expression: predicate!).rendered(
          functionContext: FunctionContext(environment: passContext.environment!,
                                           scopeContext: scopeContext!,
                                           enclosingTypeName: contractBehaviourDeclaration.contractIdentifier.name)
      )
      wrapperFunctionDeclaration.body.append(
          Statement.expression(.rawAssembly("""
                                            assert(\(predicateExpression), 1)
                                            """,
                                            resultType: RawType.errorType))
      )
    }

    let args: [FunctionArgument] = signature.parameters.map { parameter in
      return FunctionArgument(.identifier(parameter.identifier))
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
}
