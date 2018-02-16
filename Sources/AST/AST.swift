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
  case structDeclaration(StructDeclaration)
}

public typealias RawTypeIdentifier = String

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
  public var capabilityBinding: Identifier?
  public var callerCapabilities: [CallerCapability]
  public var functionDeclarations: [FunctionDeclaration]
  public var closeBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }

  public init(contractIdentifier: Identifier, capabilityBinding: Identifier?, callerCapabilities: [CallerCapability], closeBracketToken: Token, functionDeclarations: [FunctionDeclaration]) {
    self.contractIdentifier = contractIdentifier
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.functionDeclarations = functionDeclarations
    self.closeBracketToken = closeBracketToken
  }
}

public enum StructMember {
  case variableDeclaration(VariableDeclaration)
  case functionDeclaration(FunctionDeclaration)
}

public struct StructDeclaration {
  public var structToken: Token
  public var identifier: Identifier
  public var members: [StructMember]

  public var variableDeclarations: [VariableDeclaration] {
    return members.flatMap { member in
      guard case .variableDeclaration(let variableDeclaration) = member else { return nil }
      return variableDeclaration
    }
  }

  public var functionDeclarations: [FunctionDeclaration] {
    return members.flatMap { member in
      guard case .functionDeclaration(let functionDeclaration) = member else { return nil }
      return functionDeclaration
    }
  }

  public init(structToken: Token, identifier: Identifier, members: [StructMember]) {
    self.structToken = structToken
    self.identifier = identifier
    self.members = members
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
  public var attributes: [Attribute]
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

  public var sourceLocation: SourceLocation {
    if let resultType = resultType {
      return .spanning(funcToken, to: resultType)
    }
    return .spanning(funcToken, to: closeBracketToken)
  }

  public var isMutating: Bool {
    return hasModifier(kind: .mutating)
  }

  public var isPayable: Bool {
    return attributes.contains { $0.kind == .payable }
  }

  public var firstPayableValueParameter: Parameter? {
    return parameters.first { $0.isPayableValueParameter }
  }

  public var explicitParameters: [Parameter] {
    return parameters.filter { !$0.isImplicit }
  }
  
  public var parametersAsVariableDeclarations: [VariableDeclaration] {
    return parameters.map { parameter in
      return VariableDeclaration(varToken: nil, identifier: parameter.identifier, type: parameter.type)
    }
  }

  public var mutatingToken: Token {
    return modifiers.first { $0.kind == .mutating }!
  }

  public var isPublic: Bool {
    return hasModifier(kind: .public)
  }

  public init(funcToken: Token, attributes: [Attribute], modifiers: [Token], identifier: Identifier, parameters: [Parameter], closeBracketToken: Token, resultType: Type?, body: [Statement], closeBraceToken: Token) {
    self.funcToken = funcToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.resultType = resultType
    self.body = body
    self.closeBraceToken = closeBraceToken
  }

  private func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind } 
  }
}

public struct Attribute {
  var kind: Kind
  var token: Token

  public init?(token: Token) {
    guard case .attribute(let attribute) = token.kind, let kind = Kind(rawValue: attribute) else { return nil }
    self.kind = kind
    self.token = token
  }

  enum Kind: String {
    case payable
  }
}

public struct Parameter: SourceEntity {
  public var identifier: Identifier
  public var type: Type

  public var implicitToken: Token?

  public var isImplicit: Bool {
    return implicitToken != nil
  }

  public var isInout: Bool {
    if case .inoutType = type.rawType {
      return true
    }
    
    return false
  }

  public var isPayableValueParameter: Bool {
    if isImplicit, case .builtInType(let type) = type.rawType, type.isCurrencyType {
      return true
    }
    return false
  }

  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: type)
  }

  public init(identifier: Identifier, type: Type, implicitToken: Token?) {
    self.identifier = identifier
    self.type = type
    self.implicitToken = implicitToken
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
  public var enclosingType: String? = nil

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

  public var hashValue: Int {
    return "\(name)_\(sourceLocation)".hashValue
  }
}

public struct Type: SourceEntity {
  public indirect enum RawType: Equatable {
    case builtInType(BuiltInType)
    case arrayType(RawType)
    case fixedSizeArrayType(RawType, size: Int)
    case dictionaryType(key: RawType, value: RawType)
    case userDefinedType(RawTypeIdentifier)
    case inoutType(RawType)
    case errorType

    public static func ==(lhs: RawType, rhs: RawType) -> Bool {
      switch (lhs, rhs) {
      case (.builtInType(let lhsType), .builtInType(let rhsType)):
        return lhsType == rhsType
      case (.userDefinedType(let lhsType), .userDefinedType(let rhsType)):
        return lhsType == rhsType
      case (.arrayType(let lhsType), .arrayType(let rhsType)):
        return lhsType == rhsType
      case (.fixedSizeArrayType(let lhsType, let lhsSize), .fixedSizeArrayType(let rhsType, let rhsSize)):
        return lhsType == rhsType && lhsSize == rhsSize
      case (.dictionaryType(let lhsKeyType, let lhsValueType), .dictionaryType(let rhsKeyType, let rhsValueType)):
        return lhsKeyType == rhsKeyType && lhsValueType == rhsValueType
      case (.errorType, .errorType):
        return true
      case (.inoutType(let lhs), .inoutType(let rhs)):
        return lhs == rhs
      default:
        return false
      }
    }

    public var name: String {
      switch self {
      case .fixedSizeArrayType(let rawType, size: let size): return "\(rawType.name)[\(size)]"
      case .arrayType(let rawType): return "[\(rawType.name)]"
      case .builtInType(let builtInType): return "\(builtInType.rawValue)"
      case .dictionaryType(let keyType, let valueType): return "[\(keyType.name): \(valueType.name)]"
      case .userDefinedType(let identifier): return identifier
      case .inoutType(let rawType): return "&\(rawType)"
      case .errorType: return "Flint$ErrorType"
      }
    }

    public var isBasicType: Bool {
      if case .builtInType(_) = self { return true }
      return false
    }

    public var isEventType: Bool {
      return self == .builtInType(.event)
    }
  }

  public enum BuiltInType: String {
    case address = "Address"
    case int = "Int"
    case string = "String"
    case void = "Void"
    case bool = "Bool"
    case wei = "Wei"
    case event = "Event"

    var isCallerCapabilityType: Bool {
      switch self {
      case .address: return true
      default: return false
      }
    }

    var isCurrencyType: Bool {
      switch self {
      case .wei: return true
      default: return false
      }
    }
  }

  public var rawType: RawType
  public var genericArguments = [Type]()
  public var sourceLocation: SourceLocation

  public var name: String {
    return rawType.name
  }

  public init(identifier: Identifier, genericArguments: [Type] = []) {
    let name = identifier.name
    if let builtInType = BuiltInType(rawValue: name) {
      rawType = .builtInType(builtInType)
    } else {
      rawType = .userDefinedType(name)
    }
    self.genericArguments = genericArguments
    self.sourceLocation = identifier.sourceLocation
  }
  
  public init(ampersandToken: Token, inoutType: Type) {
    rawType = .inoutType(inoutType.rawType)
    sourceLocation = ampersandToken.sourceLocation
  }
  
  public init(inoutToken: Token, inoutType: Type) {
    rawType = .inoutType(inoutType.rawType)
    sourceLocation = inoutToken.sourceLocation
  }

  public init(openSquareBracketToken: Token, arrayWithElementType type: Type, closeSquareBracketToken: Token) {
    rawType = .arrayType(type.rawType)
    sourceLocation = .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(fixedSizeArrayWithElementType type: Type, size: Int, closeSquareBracketToken: Token) {
    rawType = .fixedSizeArrayType(type.rawType, size: size)
    sourceLocation = .spanning(type, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, dictionaryWithKeyType keyType: Type, valueType: Type, closeSquareBracketToken: Token) {
    rawType = .dictionaryType(key: keyType.rawType, value: valueType.rawType)
    sourceLocation = .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(inferredType: Type.RawType, identifier: Identifier) {
    rawType = inferredType
    sourceLocation = identifier.sourceLocation
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
  case inoutExpression(InoutExpression)
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
    case .inoutExpression(let inoutExpression): return inoutExpression.sourceLocation
    case .binaryExpression(let binaryExpression): return binaryExpression.sourceLocation
    case .functionCall(let functionCall): return functionCall.sourceLocation
    case .literal(let literal): return literal.sourceLocation
    case .self(let `self`): return self.sourceLocation
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.sourceLocation
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.sourceLocation
    case .subscriptExpression(let subscriptExpression): return subscriptExpression.sourceLocation
    }
  }

  public mutating func assigningEnclosingType(type: String) -> Expression {
    switch self {
    case .identifier(var identifier):
      identifier.enclosingType = type
      return .identifier(identifier)
    case .binaryExpression(var binaryExpression):
      binaryExpression.lhs = binaryExpression.lhs.assigningEnclosingType(type: type)
      return .binaryExpression(binaryExpression)
    case .bracketedExpression(var expression):
      return .bracketedExpression(expression.assigningEnclosingType(type: type))
    case .subscriptExpression(var subscriptExpression):
      subscriptExpression.baseIdentifier.enclosingType = type
      return .subscriptExpression(subscriptExpression)
    case .functionCall(var functionCall):
      functionCall.identifier.enclosingType = type
      return .functionCall(functionCall)
    default:
      return self
    }
  }
  
  public var enclosingType: String? {
    guard case .identifier(let identifier) = self else {
      return nil
    }
    
    return identifier.enclosingType
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

public struct InoutExpression: SourceEntity {
  public var ampersandToken: Token
  public var expression: Expression
  
  public var sourceLocation: SourceLocation {
    return ampersandToken.sourceLocation
  }
  
  public init(ampersandToken: Token, expression: Expression) {
    self.ampersandToken = ampersandToken
    self.expression = expression
  }
}

public struct BinaryExpression: SourceEntity {
  public var lhs: Expression

  public var op: Token

  public var opToken: Token.Kind.Punctuation {
    guard case .punctuation(let token) = op.kind else { fatalError() }
    return token
  }

  public var rhs: Expression

  public var isExplicitPropertyAccess: Bool {
    if case .dot = opToken, case .self(_) = lhs {
      return true
    }
    return false
  }

  public var sourceLocation: SourceLocation {
    return .spanning(lhs, to: rhs)
  }

  public init(lhs: Expression, op: Token, rhs: Expression) {
    self.lhs = lhs

    guard case .punctuation(_) = op.kind else {
      fatalError("Unexpected token kind \(op.kind) when trying to form a binary expression.")
    }

    self.op = op
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

