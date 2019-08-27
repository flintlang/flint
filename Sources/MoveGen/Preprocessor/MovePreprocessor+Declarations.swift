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

  func generateParameterAssignedFunctions(_ base: FunctionDeclaration,
                                          enclosingType: String,
                                          passContext: inout ASTPassContext) -> [FunctionDeclaration] {
    let defaultParameters = base.signature.parameters.filter { $0.assignedExpression != nil }.reversed()
    var functions = [base]

    for parameter: Parameter in defaultParameters {
      var processed = [FunctionDeclaration]()
      for function in functions {
        var parameterAssignedFunction = function
        var defaultRemovedFunction = function

        parameterAssignedFunction.signature.parameters = parameterAssignedFunction.signature.parameters
            .filter { $0.identifier.name != parameter.identifier.name }
        defaultRemovedFunction.signature.parameters = defaultRemovedFunction.signature.parameters
            .map { (p: Parameter) in
          if p.identifier.name == parameter.identifier.name {
            var defaultRemoved = p
            defaultRemoved.assignedExpression = nil
            return defaultRemoved
          }
          return p
        }

        parameterAssignedFunction.scopeContext?.parameters = parameterAssignedFunction.signature.parameters
        parameterAssignedFunction.scopeContext?.localVariables = []

        // Note, the initial function may be duplicated by the TraitResolver
        // Remove current function to add default removed function
        passContext.environment?.removeFunction(
            function,
            enclosingType: enclosingType,
            states: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
            callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
        )
        passContext.environment?.addFunction(
            defaultRemovedFunction,
            enclosingType: enclosingType,
            states: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
            callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
        )
        processed.append(defaultRemovedFunction)

        // TODO fix by maybe mangling argument names into function names?
        //  Right now we cannot have two functions with the same name and type,
        //  so we're just generating the one with the last/most likely parameter filled in
        let parameterTypes = { (f: FunctionDeclaration) in f.signature.parameters.map { $0.type.rawType.name } }
        guard !functions.contains(
            where: { parameterTypes($0) == parameterTypes(parameterAssignedFunction) }
        ) else {
          continue
        }

        let arguments = function.explicitParameters.map { (p: Parameter) -> FunctionArgument in
          if p.identifier.name == parameter.identifier.name {
            var expression = parameter.assignedExpression!
            return FunctionArgument(identifier: p.identifier,
                                    expression: expression.assigningEnclosingType(type: enclosingType))
          }
          return FunctionArgument(identifier: p.identifier, expression: .identifier(p.identifier))
        }
        if parameterAssignedFunction.signature.resultType != nil {
          parameterAssignedFunction.body = [.returnStatement(
              ReturnStatement(returnToken: Token(kind: .return, sourceLocation: parameter.sourceLocation),
                              expression: .functionCall(FunctionCall(
                                  identifier: function.identifier,
                                  arguments: arguments,
                                  closeBracketToken: Token(kind: .punctuation(.closeBracket),
                                                           sourceLocation: parameter.sourceLocation),
                                  isAttempted: false
                              )))
          )]
        } else {
          parameterAssignedFunction.body = [
            .expression(.functionCall(FunctionCall(
                identifier: function.identifier,
                arguments: arguments,
                closeBracketToken: Token(kind: .punctuation(.closeBracket),
                                         sourceLocation: parameter.sourceLocation),
                isAttempted: false
            )))
          ]
        }
        passContext.environment?.addFunction(
            parameterAssignedFunction,
            enclosingType: enclosingType,
            states: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
            callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
        )
        processed.append(parameterAssignedFunction)
      }
      functions = processed
    }
    return functions
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var contractBehaviorDeclaration = contractBehaviorDeclaration
    var passContext = passContext
    contractBehaviorDeclaration.members = contractBehaviorDeclaration.members
        .flatMap { (member: ContractBehaviorMember) -> [ContractBehaviorMember] in
      if case .functionDeclaration(let function) = member {
        return generateParameterAssignedFunctions(
            function,
            enclosingType: contractBehaviorDeclaration.contractIdentifier.name,
            passContext: &passContext
        ).map { .functionDeclaration($0) }
      }
      return [member]
    }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    var structDeclaration = structDeclaration
    var passContext = passContext
    structDeclaration.members = structDeclaration.members
        .flatMap { (member: StructMember) -> [StructMember] in
      if case .functionDeclaration(let function) = member {
        return generateParameterAssignedFunctions(
            function,
            enclosingType: structDeclaration.identifier.name,
            passContext: &passContext
        ).map { .functionDeclaration($0) }
      }
      return [member]
    }
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration
    var passContext = passContext

    // Mangle the function name in the declaration.
    let parameters = functionDeclaration.signature.parameters.rawTypes
    let name = Mangler.mangleFunctionName(functionDeclaration.identifier.name,
                                          parameterTypes: parameters,
                                          enclosingType: passContext.enclosingTypeIdentifier!.name)
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
      let parameter = Parameter.constructThisParameter(
        type: .userDefinedType(structDeclarationContext.structIdentifier.name),
        sourceLocation: functionDeclaration.sourceLocation)
      functionDeclaration.signature.parameters.insert(parameter, at: 0)
      passContext.scopeContext?.parameters.insert(parameter, at: 0)
    } else if let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext,
              Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
      let parameter = Parameter.constructThisParameter(
        type: .userDefinedType(contractBehaviorDeclarationContext.contractIdentifier.name),
        sourceLocation: functionDeclaration.sourceLocation)

      functionDeclaration.signature.parameters.insert(parameter, at: 0)
      passContext.scopeContext?.parameters.insert(parameter, at: 0)

      if let callerBindingIdentifier = contractBehaviorDeclarationContext.callerBinding {
        functionDeclaration.body.insert(
            MovePreprocessor.generateCallerBindingStatement(callerBindingIdentifier: callerBindingIdentifier),
            at: 0
        )
      }
    }

    functionDeclaration.scopeContext?.parameters = functionDeclaration.signature.parameters

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration
    functionDeclaration.body = getDeclarations(passContext: passContext)
      + deleteDeclarations(in: functionDeclaration.body)

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
      guard let last = functionDeclaration.body.last(where: { (statement: Statement) in
        switch statement {
        case .expression(.rawAssembly): return false
        default: return true
        }
      }) else {
        fatalError("AAAAHHHHHHHHHHHHHHHHH!")
      }
      // Add return variable
      let returnVariableDeclaration = VariableDeclaration(
        modifiers: [],
        declarationToken: nil,
        identifier: Identifier(name: MoveFunction.returnVariableName,
                               sourceLocation: last.sourceLocation),
        type: functionDeclaration.signature.resultType!)
      functionDeclaration.body.insert(.expression(.variableDeclaration(returnVariableDeclaration)), at: 0)
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    if let callerBindingIdentifier = passContext.contractBehaviorDeclarationContext?.callerBinding {
      specialDeclaration.body.insert(
        MovePreprocessor.generateCallerBindingStatement(callerBindingIdentifier: callerBindingIdentifier),
        at: 0)
    }
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    specialDeclaration.body = getDeclarations(passContext: passContext)
      + deleteDeclarations(in: specialDeclaration.body)
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var contractBehaviorDeclaration = contractBehaviorDeclaration
    contractBehaviorDeclaration.members = contractBehaviorDeclaration.members
        .flatMap { member -> [ContractBehaviorMember] in
      guard case .functionDeclaration(var functionDeclaration) = member else {
        return [member]
      }
      let wrapperFunctionDeclaration: FunctionDeclaration = functionDeclaration.generateContractWrapper(
          contractBehaviourDeclaration: contractBehaviorDeclaration,
          passContext: passContext
      )
      functionDeclaration.signature.modifiers.removeAll(where: { $0.kind == .`public` })
      return [.functionDeclaration(functionDeclaration),
              .functionDeclaration(wrapperFunctionDeclaration)]
    }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public static func generateCallerBindingStatement(callerBindingIdentifier: Identifier) -> Statement {
    let callerBindingAssignment = BinaryExpression(
      lhs: .identifier(callerBindingIdentifier),
      op: Token(kind: .punctuation(.equal),
                sourceLocation: callerBindingIdentifier.sourceLocation),
      rhs: .rawAssembly("get_txn_sender()", resultType: .basicType(.address)))
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
        if case .variableDeclaration = expression {
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
