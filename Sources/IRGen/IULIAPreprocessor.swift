//
//  IULIAPreprocessor.swift
//  IRGen
//
//  Created by Franklin Schrans on 2/1/18.
//

import AST

import Foundation
import AST

/// A prepocessing step to update the program's AST before code generation.
public struct IULIAPreprocessor: ASTPass {

  public init() {}

  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    var structMember = structMember

    if case .initializerDeclaration(var initializerDeclaration) = structMember {
      initializerDeclaration.body.insert(contentsOf: defaultValueAssignments(in: passContext), at: 0)
      // Convert the initializer to a function.
      structMember = .functionDeclaration(initializerDeclaration.asFunctionDeclaration)
    }

    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func process(enumCase: EnumCase, passContext: ASTPassContext) -> ASTPassResult<EnumCase> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }

  public func process(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }

  /// Returns assignment statements for all the properties which have been assigned default values.
  func defaultValueAssignments(in passContext: ASTPassContext) -> [Statement] {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let propertiesInEnclosingType = passContext.environment!.propertyDeclarations(in: enclosingType)

    return propertiesInEnclosingType.compactMap { declaration -> Statement? in
      guard let assignedExpression = declaration.value else { return nil }

      var identifier = declaration.identifier
      identifier.enclosingType = enclosingType

      return .expression(.binaryExpression(BinaryExpression(lhs: .identifier(identifier), op: Token(kind: .punctuation(.equal), sourceLocation: identifier.sourceLocation), rhs: assignedExpression)))
    }
  }

  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext

    if let _ = passContext.functionDeclarationContext {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration

    // Mangle the function name in the declaration.
    let parameters = functionDeclaration.parameters.map { $0.type.rawType }
    let name = Mangler.mangleFunctionName(functionDeclaration.identifier.name, parameterTypes: parameters, enclosingType: passContext.enclosingTypeIdentifier!.name)
    functionDeclaration.mangledIdentifier = name

    // Bind the implicit Wei value of the transaction to a variable.
    if functionDeclaration.isPayable, let payableParameterIdentifier = functionDeclaration.firstPayableValueParameter?.identifier {
      let weiType = Identifier(identifierToken: Token(kind: .identifier("Wei"), sourceLocation: payableParameterIdentifier.sourceLocation))
      let variableDeclaration = VariableDeclaration(declarationToken: nil, identifier: payableParameterIdentifier, type: Type(identifier: weiType))
      let closeBracketToken = Token(kind: .punctuation(.closeBracket), sourceLocation: payableParameterIdentifier.sourceLocation)
      let wei = FunctionCall(identifier: weiType, arguments: [.rawAssembly(IULIARuntimeFunction.callvalue(), resultType: .basicType(.int))], closeBracketToken: closeBracketToken)
      let equal = Token(kind: .punctuation(.equal), sourceLocation: payableParameterIdentifier.sourceLocation)
      let assignment: Expression = .binaryExpression(BinaryExpression(lhs: .variableDeclaration(variableDeclaration), op: equal, rhs: .functionCall(wei)))
      functionDeclaration.body.insert(.expression(assignment), at: 0)
    }

    if let structDeclarationContext = passContext.structDeclarationContext {
      if Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
        // For struct functions, add `flintSelf` to the beginning of the parameters list.
        let parameter = constructParameter(name: "flintSelf", type: .inoutType(.userDefinedType(structDeclarationContext.structIdentifier.name)), sourceLocation: functionDeclaration.sourceLocation)
        functionDeclaration.parameters.insert(parameter, at: 0)
      }
    }

    // Add an isMem parameter for each struct parameter.
    let dynamicParameters = functionDeclaration.parameters.enumerated().filter { $0.1.type.rawType.isDynamicType }

    var offset = 0
    for (index, parameter) in dynamicParameters where !parameter.isImplicit {
      let isMemParameter = constructParameter(name: Mangler.isMem(for: parameter.identifier.name), type: .basicType(.bool), sourceLocation: parameter.sourceLocation)
      functionDeclaration.parameters.insert(isMemParameter, at: index + 1 + offset)
      offset += 1
    }

    functionDeclaration.scopeContext?.parameters = functionDeclaration.parameters
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  func constructParameter(name: String, type: Type.RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation))
    return Parameter(identifier: identifier, type: Type(inferredType: type, identifier: identifier), implicitToken: nil)
  }

  public func process(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    var initializerDeclaration = initializerDeclaration
    initializerDeclaration.body.insert(contentsOf: defaultValueAssignments(in: passContext), at: 0)
    return ASTPassResult(element: initializerDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func process(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }

  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var expression = expression
    let environment = passContext.environment!

    if case .binaryExpression(let binaryExpression) = expression {

      if case .dot = binaryExpression.opToken,
         case .identifier(let lhsId) = binaryExpression.lhs,
         case .identifier(let rhsId) = binaryExpression.rhs,
         environment.isEnumDeclared(lhsId.name),
         let matchingProperty = environment.propertyDeclarations(in: lhsId.name).filter({ $0.identifier.identifierToken.kind == rhsId.identifierToken.kind }).first,
         matchingProperty.type!.rawType != .errorType {
          expression = matchingProperty.value!
      } else if case .equal = binaryExpression.opToken,
                case .functionCall(var functionCall) = binaryExpression.rhs {

        let ampersandToken: Token = Token(kind: .punctuation(.ampersand), sourceLocation: binaryExpression.lhs.sourceLocation)

        if environment.isInitializerCall(functionCall) {
          // If we're initializing a struct, pass the lhs expression as the first parameter of the initializer call.
          let inoutExpression = InoutExpression(ampersandToken: ampersandToken, expression: binaryExpression.lhs)
          functionCall.arguments.insert(.inoutExpression(inoutExpression), at: 0)

          expression = .functionCall(functionCall)

          if case .variableDeclaration(let variableDeclaration) = binaryExpression.lhs,
            variableDeclaration.type.rawType.isDynamicType {
            functionCall.arguments[0] = .inoutExpression(InoutExpression(ampersandToken: ampersandToken, expression: .identifier(variableDeclaration.identifier)))
            expression = .sequence([.variableDeclaration(variableDeclaration), .functionCall(functionCall)])
          }
        }
      }
    }

    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var passContext = passContext
    var binaryExpression = binaryExpression

    if let op = binaryExpression.opToken.operatorAssignmentOperator {
      let sourceLocation = binaryExpression.op.sourceLocation
      let token = Token(kind: .punctuation(op), sourceLocation: sourceLocation)
      binaryExpression.op = Token(kind: .punctuation(.equal), sourceLocation: sourceLocation)
      binaryExpression.rhs = .binaryExpression(BinaryExpression(lhs: binaryExpression.lhs, op: token, rhs: binaryExpression.rhs))
    } else if case .dot = binaryExpression.opToken {
      let trail = passContext.functionCallReceiverTrail ?? []
      passContext.functionCallReceiverTrail = trail + [binaryExpression.lhs]
    }

    // Convert <= and >= expressions.
    if [.lessThanOrEqual, .greaterThanOrEqual].contains(binaryExpression.opToken) {
      let strictOperator: Token.Kind.Punctuation = binaryExpression.opToken == .lessThanOrEqual ? .openAngledBracket : .closeAngledBracket

      var lhsExpression = binaryExpression
      lhsExpression.op = Token(kind: .punctuation(strictOperator), sourceLocation: lhsExpression.op.sourceLocation)

      var rhsExpression = binaryExpression
      rhsExpression.op = Token(kind: .punctuation(.doubleEqual), sourceLocation: rhsExpression.op.sourceLocation)

      binaryExpression.lhs = .binaryExpression(lhsExpression)
      binaryExpression.rhs = .binaryExpression(rhsExpression)

      let sourceLocation = binaryExpression.op.sourceLocation
      binaryExpression.op = Token(kind: .punctuation(.or), sourceLocation: sourceLocation)
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  func constructExpression<Expressions: Sequence & RandomAccessCollection>(from expressions: Expressions) -> Expression where Expressions.Element == Expression {
    guard expressions.count > 1 else { return expressions.first! }
    let head = expressions.first!
    let tail = expressions.dropFirst()

    let op = Token(kind: .punctuation(.dot), sourceLocation: head.sourceLocation)
    return .binaryExpression(BinaryExpression(lhs: head, op: op, rhs: constructExpression(from: tail)))
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var functionCall = functionCall
    let environment = passContext.environment!
    var receiverTrail = passContext.functionCallReceiverTrail ?? []
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerCapabilities = passContext.contractBehaviorDeclarationContext?.callerCapabilities ?? []
    let isGlobalFunctionCall = self.isGlobalFunctionCall(functionCall, in: passContext)

    let scopeContext = passContext.scopeContext!

    guard !Environment.isRuntimeFunctionCall(functionCall) else {
      // Don't further process runtime functions.
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    if receiverTrail.isEmpty {
      receiverTrail = [.self(Token(kind: .self, sourceLocation: functionCall.sourceLocation))]
    }

    // Mangle initializer call.
    if environment.isStructDeclared(functionCall.identifier.name) {
      // Remove the receiver as the first argument to find the original initializer declaration.
      var initializerWithoutReceiver = functionCall
      if passContext.functionDeclarationContext != nil || passContext.initializerDeclarationContext != nil {
        initializerWithoutReceiver.arguments.remove(at: 0)
      }

      functionCall.mangledIdentifier = mangledFunctionName(for: initializerWithoutReceiver, in: passContext)
    } else {
      // Get the result type of the call.
      let declarationEnclosingType: RawTypeIdentifier

      if isGlobalFunctionCall {
        declarationEnclosingType = Environment.globalFunctionStructName
      } else {
        declarationEnclosingType = passContext.environment!.type(of: receiverTrail.last!, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext).name
      }

      // Set the mangled identifier for the function.
      functionCall.mangledIdentifier = mangledFunctionName(for: functionCall, in: passContext)

      // If it returns a dynamic type, pass the receiver as the first parameter.
      if passContext.environment!.isStructDeclared(declarationEnclosingType) {
        if !isGlobalFunctionCall {
          let receiver = constructExpression(from: receiverTrail)
          let inoutExpression = InoutExpression(ampersandToken: Token(kind: .punctuation(.ampersand), sourceLocation: receiver.sourceLocation), expression: receiver)
          functionCall.arguments.insert(.inoutExpression(inoutExpression), at: 0)
        }
      }
    }

    guard environment.matchEventCall(functionCall, enclosingType: enclosingType) == nil else {
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    // For each non-implicit dynamic type, add an isMem parameter.
    var offset = 0
    for (index, argument) in functionCall.arguments.enumerated() {
      let isMem: Expression

      if let parameterName = scopeContext.enclosingParameter(expression: argument, enclosingTypeName: enclosingType),
        scopeContext.isParameterImplicit(parameterName) {
        isMem = .literal(Token(kind: .literal(.boolean(.true)), sourceLocation: argument.sourceLocation))
      } else {
        let type = passContext.environment!.type(of: argument, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext)
        guard type != .errorType else { fatalError() }
        guard type.isDynamicType else { continue }

        if let enclosingIdentifier = argument.enclosingIdentifier, scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
          // If the argument is declared locally, it's stored in memory.
          isMem = .literal(Token(kind: .literal(.boolean(.true)), sourceLocation: argument.sourceLocation))
        } else if let enclosingIdentifier = argument.enclosingIdentifier, scopeContext.containsParameterDeclaration(for: enclosingIdentifier.name) {
          // If the argument is a parameter to the enclosing function, use its isMem parameter.
          isMem = .identifier(Identifier(identifierToken: Token(kind: .identifier(Mangler.isMem(for: enclosingIdentifier.name)), sourceLocation: argument.sourceLocation)))
        } else if case .inoutExpression(let inoutExpression) = argument, case .self(_) = inoutExpression.expression {
          // If the argument is self, use flintSelf
          isMem = .identifier(Identifier(identifierToken: Token(kind: .identifier(Mangler.isMem(for: "flintSelf")), sourceLocation: argument.sourceLocation)))
        } else {
          // Otherwise, the argument refers to a property, which is not in memory.
          isMem = .literal(Token(kind: .literal(.boolean(.false)), sourceLocation: argument.sourceLocation))
        }
      }

      functionCall.arguments.insert(isMem, at: index + offset + 1)
      offset += 1
    }

    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  func mangledFunctionName(for functionCall: FunctionCall, in passContext: ASTPassContext) -> String? {
    // Don't mangle runtime functions
    guard !Environment.isRuntimeFunctionCall(functionCall) else {
      return functionCall.identifier.name
    }

    let environment = passContext.environment!

    let enclosingType: String = functionCall.identifier.enclosingType ?? passContext.enclosingTypeIdentifier!.name

    // Don't mangle event calls
    if environment.matchEventCall(functionCall, enclosingType: enclosingType) != nil {
      return functionCall.identifier.name
    }

    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerCapabilities = passContext.contractBehaviorDeclarationContext?.callerCapabilities ?? []
    let matchResult = environment.matchFunctionCall(functionCall, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: passContext.scopeContext!)

    switch matchResult {
    case .matchedFunction(let functionInformation):
      let declaration = functionInformation.declaration
      let parameterTypes = declaration.parameters.map { $0.type.rawType }
      return Mangler.mangleFunctionName(declaration.identifier.name, parameterTypes: parameterTypes, enclosingType: enclosingType)
    case .matchedInitializer(let initializerInformation):
      let declaration = initializerInformation.declaration
      let parameterTypes = declaration.parameters.map { $0.type.rawType }
      return Mangler.mangleInitializerName(functionCall.identifier.name, parameterTypes: parameterTypes)
    case .matchedGlobalFunction(let functionInformation):
      let parameterTypes = functionInformation.declaration.parameters.map { $0.type.rawType }
      return Mangler.mangleFunctionName(functionCall.identifier.name, parameterTypes: parameterTypes, enclosingType: Environment.globalFunctionStructName)
    case .failure(_):
      return nil
    }
  }

  func isGlobalFunctionCall(_ functionCall: FunctionCall, in passContext: ASTPassContext) -> Bool {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerCapabilities = passContext.contractBehaviorDeclarationContext?.callerCapabilities ?? []
    let scopeContext = passContext.scopeContext!
    let environment = passContext.environment!

    let match = environment.matchFunctionCall(functionCall, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    // Mangle global function
    if case .matchedGlobalFunction(_) = match {
      return true
    }

    return false
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(rangeExpression: AST.RangeExpression, passContext: ASTPassContext) -> ASTPassResult<AST.RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }

  public func process(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var becomeStatement = becomeStatement

    let enumName = ContractDeclaration.contractEnumPrefix + passContext.enclosingTypeIdentifier!.name
    let enumReference: Expression = .identifier(Identifier(identifierToken: Token(kind: .identifier(enumName), sourceLocation: becomeStatement.sourceLocation)))
    let state = becomeStatement.expression.assigningEnclosingType(type: enumName)

    let dot = Token(kind: .punctuation(.dot), sourceLocation: becomeStatement.sourceLocation)

    becomeStatement.expression = .binaryExpression(BinaryExpression(lhs: enumReference, op: dot, rhs: state))

    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(enumCase: EnumCase, passContext: ASTPassContext) -> ASTPassResult<EnumCase> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }

  public func postProcess(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    return ASTPassResult(element: initializerDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func postProcess(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }

  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func postProcess(rangeExpression: AST.RangeExpression, passContext: ASTPassContext) -> ASTPassResult<AST.RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
  }

  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }
}

extension ASTPassContext {
  var functionCallReceiverTrail: [Expression]? {
    get { return self[FunctionCallReceiverTrailContextEntry.self] }
    set { self[FunctionCallReceiverTrailContextEntry.self] = newValue }
  }
}

struct FunctionCallReceiverTrailContextEntry: PassContextEntry {
  typealias Value = [Expression]
}
