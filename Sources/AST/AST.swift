public protocol SourceEntity {
  var sourceLocation: SourceLocation { get }
}

public struct TopLevelModule {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
  }
}

public enum TopLevelDeclaration {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
}

public struct ContractDeclaration: SourceEntity {
  public var contractToken: Token
  public var identifier: Identifier
  public var variableDeclarations: [VariableDeclaration]

  public var sourceLocation: SourceLocation {
    return .spanning(contractToken, to: identifier)
  }

  public init(contractToken: Token, identifier: Identifier, variableDeclarations: [VariableDeclaration]) {
    self.identifier = identifier
    self.variableDeclarations = variableDeclarations
    self.contractToken = contractToken
  }
}

public struct ContractBehaviorDeclaration: SourceEntity {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]
  public var functionDeclarations: [FunctionDeclaration]
  public var closeBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }

  public init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability], closeBracketToken: Token, functionDeclarations: [FunctionDeclaration]) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
    self.functionDeclarations = functionDeclarations
    self.closeBracketToken = closeBracketToken
  }
}

public struct VariableDeclaration: SourceEntity {
  public var varToken: Token?
  public var identifier: Identifier
  public var type: Type

  public var sourceLocation: SourceLocation {
    if let varToken = varToken {
      return .spanning(varToken, to: type)
    }
    return .spanning(identifier, to: type)
  }

  public init(varToken: Token?, identifier: Identifier, type: Type) {
    self.varToken = varToken
    self.identifier = identifier
    self.type = type
  }
}

public struct FunctionDeclaration: SourceEntity {
  public var funcToken: Token
  public var modifiers: [Token]
  public var identifier: Identifier
  public var parameters: [Parameter]
  public var closeBracketToken: Token
  public var resultType: Type?
  public var body: [Statement]
  public var closeBraceToken: Token

  public var rawType: Type.RawType {
    return resultType?.rawType ?? .builtInType(.void)
  }

  public var localVariables: [VariableDeclaration]

  public var sourceLocation: SourceLocation {
    if let resultType = resultType {
      return .spanning(funcToken, to: resultType)
    }
    return .spanning(funcToken, to: closeBracketToken)
  }

  public var isMutating: Bool {
    return hasModifier(kind: .mutating)
  }

  public var isPublic: Bool {
    return hasModifier(kind: .public)
  }

  public init(funcToken: Token, modifiers: [Token], identifier: Identifier, parameters: [Parameter], closeBracketToken: Token, resultType: Type?, body: [Statement], closeBraceToken: Token, localVariables: [VariableDeclaration]) {
    self.funcToken = funcToken
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.resultType = resultType
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.localVariables = localVariables
  }

  public func mangled(inContract contract: Identifier, withCallerCapabilities callerCapabilities: [CallerCapability]) -> MangledFunction {
    return MangledFunction(functionDeclaration: self, contractIdentifier: contract, callerCapabilities: callerCapabilities)
  }

  private func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind } 
  }

  public func matchingLocalVariable(_ identifier: Identifier) -> VariableDeclaration? {
    return localVariables.first { $0.identifier.name ==  identifier.name }
  }
}

public struct Parameter: SourceEntity {
  public var identifier: Identifier
  public var type: Type

  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: type)
  }

  public init(identifier: Identifier, type: Type) {
    self.identifier = identifier
    self.type = type
  }
}

public struct TypeAnnotation: SourceEntity {
  public var colonToken: Token
  public var type: Type

  public var sourceLocation: SourceLocation {
    return .spanning(colonToken, to: type)
  }

  public init(colonToken: Token, type: Type) {
    self.colonToken = colonToken
    self.type = type
  }
}

public struct Identifier: Hashable, SourceEntity {
  public var identifierToken: Token
  public var enclosingContractName: String?

  public var isPropertyAccess: Bool {
    return enclosingContractName != nil
  }

  public var name: String {
    guard case .identifier(let name) = identifierToken.kind else { fatalError() }
    return name
  }

  public var sourceLocation: SourceLocation {
    return identifierToken.sourceLocation
  }

  public init(identifierToken: Token) {
    self.identifierToken = identifierToken
  }

  public func mangled(in contractIdentifier: Identifier) -> MangledProperty {
    return MangledProperty(inContract: self, contractIdentifier: contractIdentifier)
  }

  public var hashValue: Int {
    return "\(name)_\(sourceLocation)".hashValue
  }
}

public struct Type: SourceEntity {
  public indirect enum RawType: Equatable {
    case builtInType(BuiltInType)
    case arrayType(RawType, size: Int)
    case dictionaryType(key: RawType, value: RawType)
    case userDefinedType(String)
    case errorType

    public static func ==(lhs: RawType, rhs: RawType) -> Bool {
      switch (lhs, rhs) {
      case (.builtInType(let lhsType), .builtInType(let rhsType)):
        return lhsType == rhsType
      case (.userDefinedType(let lhsType), .userDefinedType(let rhsType)):
        return lhsType == rhsType
      case (.arrayType(let lhsType, let lhsSize), .arrayType(let rhsType, let rhsSize)):
        return lhsType == rhsType && lhsSize == rhsSize
      case (.dictionaryType(let lhsKeyType, let lhsValueType), .dictionaryType(let rhsKeyType, let rhsValueType)):
        return lhsKeyType == rhsKeyType && lhsValueType == rhsValueType
      case (.errorType, .errorType):
        return true
      default:
        return false
      }
    }

    public var size: Int {
      switch self {
      case .builtInType(_): return 1
      case .arrayType(let rawType, let size): return rawType.size * size
      case .dictionaryType(_, _): return 1
      case .userDefinedType(_): return 1
      case .errorType: return 0
      }
    }

    public var name: String {
      switch self {
      case .arrayType(let rawType, size: let size): return "\(rawType.name)[\(size)]"
      case .builtInType(let builtInType): return "\(builtInType.rawValue)"
      case .dictionaryType(let keyType, let valueType): return "[\(keyType.name): \(valueType.name)]"
      case .userDefinedType(let name): return name
      case .errorType: return "Flint$ErrorType"
      }
    }
  }

  public enum BuiltInType: String {
    case address = "Address"
    case int = "Int"
    case void = "Void"
    case bool = "Bool"

    var canBeUsedAsCallerCapability: Bool {
      switch self {
      case .address: return true
      default: return false
      }
    }
  }

  public var rawType: RawType
  public var sourceLocation: SourceLocation

  public var name: String {
    return rawType.name
  }

  public init(identifier: Identifier) {
    let name = identifier.name
    if let builtInType = BuiltInType(rawValue: name) {
      rawType = .builtInType(builtInType)
    } else {
      rawType = .userDefinedType(name)
    }
    self.sourceLocation = identifier.sourceLocation
  }

  public init(arrayWithElementType type: Type, size: Int, closeSquareBracketToken: Token) {
    rawType = .arrayType(type.rawType, size: size)
    sourceLocation = .spanning(type, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, dictionaryWithKeyType keyType: Type, valueType: Type, closeSquareBracketToken: Token) {
    rawType = .dictionaryType(key: keyType.rawType, value: valueType.rawType)
    sourceLocation = .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }
}

public struct CallerCapability: SourceEntity {
  public var identifier: Identifier

  public var sourceLocation: SourceLocation {
    return identifier.sourceLocation
  }

  public var name: String {
    return identifier.name
  }

  public var isAny: Bool {
    return name == "any"
  }

  public init(identifier: Identifier) {
    self.identifier = identifier
  }

  public func isSubcapability(callerCapability: CallerCapability) -> Bool {
    return name == callerCapability.name || callerCapability.isAny
  }
}

public indirect enum Expression: SourceEntity {
  case identifier(Identifier)
  case binaryExpression(BinaryExpression)
  case functionCall(FunctionCall)
  case literal(Token)
  case `self`(Token)
  case variableDeclaration(VariableDeclaration)
  case bracketedExpression(Expression)
  case subscriptExpression(SubscriptExpression)

  public var sourceLocation: SourceLocation {
    switch self {
    case .identifier(let identifier): return identifier.sourceLocation
    case .binaryExpression(let binaryExpression): return binaryExpression.sourceLocation
    case .functionCall(let functionCall): return functionCall.sourceLocation
    case .literal(let literal): return literal.sourceLocation
    case .self(let `self`): return self.sourceLocation
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.sourceLocation
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.sourceLocation
    case .subscriptExpression(let subscriptExpression): return subscriptExpression.sourceLocation
    }
  }
}

public indirect enum Statement: SourceEntity {
  case expression(Expression)
  case returnStatement(ReturnStatement)
  case ifStatement(IfStatement)

  public var sourceLocation: SourceLocation {
    switch self {
    case .expression(let expression): return expression.sourceLocation
    case .returnStatement(let returnStatement): return returnStatement.sourceLocation
    case .ifStatement(let ifStatement): return ifStatement.sourceLocation
    }
  }
}

public struct BinaryExpression: SourceEntity {
  public var lhs: Expression

  public var op: Token
  public var opToken: Token.Kind.BinaryOperator

  public var rhs: Expression

  public var sourceLocation: SourceLocation {
    return .spanning(lhs, to: rhs)
  }

  public init(lhs: Expression, op: Token, rhs: Expression) {
    self.lhs = lhs

    guard case .binaryOperator(let opToken) = op.kind else {
      fatalError("Unexpected token kind \(op.kind) when trying to form a binary expression.")
    }

    self.op = op
    self.opToken = opToken
    self.rhs = rhs
  }
}

public struct FunctionCall: SourceEntity {
  public var identifier: Identifier
  public var arguments: [Expression]
  public var closeBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: closeBracketToken)
  }

  public init(identifier: Identifier, arguments: [Expression], closeBracketToken: Token) {
    self.identifier = identifier
    self.arguments = arguments
    self.closeBracketToken = closeBracketToken
  }
}

public struct SubscriptExpression: SourceEntity {
  public var baseIdentifier: Identifier
  public var indexExpression: Expression
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(baseIdentifier, to: closeSquareBracketToken)
  }

  public init(baseIdentifier: Identifier, indexExpression: Expression, closeSquareBracketToken: Token) {
    self.baseIdentifier = baseIdentifier
    self.indexExpression = indexExpression
    self.closeSquareBracketToken = closeSquareBracketToken
  }
}

public struct ReturnStatement: SourceEntity {
  public var returnToken: Token
  public var expression: Expression?

  public var sourceLocation: SourceLocation {
    if let expression = expression {
      return .spanning(returnToken, to: expression)
    }

    return returnToken.sourceLocation
  }

  public init(returnToken: Token, expression: Expression?) {
    self.returnToken = returnToken
    self.expression = expression
  }
}

public struct IfStatement: SourceEntity {
  public var ifToken: Token
  public var condition: Expression
  public var body: [Statement]
  public var elseBody: [Statement]

  public var sourceLocation: SourceLocation {
    return .spanning(ifToken, to: condition)
  }

  public var endsWithReturnStatement: Bool {
    return body.contains { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    }
  }

  public init(ifToken: Token, condition: Expression, statements: [Statement], elseClauseStatements: [Statement]) {
    self.ifToken = ifToken
    self.condition = condition
    self.body = statements
    self.elseBody = elseClauseStatements
  }
}

