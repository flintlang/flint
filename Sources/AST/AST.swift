/// An entity appearing in a source file.
public protocol SourceEntity: Equatable {
  var sourceLocation: SourceLocation { get }
}

/// A Flint top-level module. Includes top-level declarations, such as contract, struct, and contract behavior
/// declarations.
public struct TopLevelModule: Equatable {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
  }
}

/// A Flint top-level declaration.
///
/// - contractDeclaration: The declaration of a contract.
/// - contractBehaviorDeclaration:  A Flint contract beheavior declaration, i.e. the functions of a contract for a given
///                                 caller capability group.
/// - structDeclaration:            The declaration of a struct.
public enum TopLevelDeclaration: Equatable {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
  case structDeclaration(StructDeclaration)
}

/// The raw representation of an `Identifier`.
public typealias RawTypeIdentifier = String

/// The declaration of a Flint contract.
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

/// A member in a contract behavior declaration.
///
/// - functionDeclaration: The declaration of a function.
/// - initializerDeclaration: The declaration of an initializer.
public enum ContractBehaviorMember: Equatable, SourceEntity {
  case functionDeclaration(FunctionDeclaration)
  case initializerDeclaration(InitializerDeclaration)

  public var sourceLocation: SourceLocation {
    switch self {
    case .functionDeclaration(let functionDeclaration): return functionDeclaration.sourceLocation
    case .initializerDeclaration(let initializerDeclaration): return initializerDeclaration.sourceLocation
    }
  }

}

/// A Flint contract behavior declaration, i.e. the functions of a contract for a given caller capability group.
public struct ContractBehaviorDeclaration: SourceEntity {
  public var contractIdentifier: Identifier
  public var capabilityBinding: Identifier?
  public var callerCapabilities: [CallerCapability]
  public var typeStates: [TypeState]?
  public var members: [ContractBehaviorMember]
  public var closeBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }

  public init(contractIdentifier: Identifier, typeStates: [TypeState]?, capabilityBinding: Identifier?, callerCapabilities: [CallerCapability], closeBracketToken: Token, members: [ContractBehaviorMember]) {
    self.contractIdentifier = contractIdentifier
    self.typeStates = typeStates
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.closeBracketToken = closeBracketToken
    self.members = members
  }
}

/// A member in a struct declaration.
///
/// - variableDeclaration: The declaration of a variable.
/// - functionDeclaration: The declaration of a function.
public enum StructMember: Equatable {
  case variableDeclaration(VariableDeclaration)
  case functionDeclaration(FunctionDeclaration)
  case initializerDeclaration(InitializerDeclaration)
}

/// The declaration of a struct.
public struct StructDeclaration: SourceEntity {
  public var structToken: Token
  public var identifier: Identifier
  public var members: [StructMember]

  public var sourceLocation: SourceLocation {
    return structToken.sourceLocation
  }

  public var variableDeclarations: [VariableDeclaration] {
    return members.compactMap { member in
      guard case .variableDeclaration(let variableDeclaration) = member else { return nil }
      return variableDeclaration
    }
  }

  public var functionDeclarations: [FunctionDeclaration] {
    return members.compactMap { member in
      guard case .functionDeclaration(let functionDeclaration) = member else { return nil }
      return functionDeclaration
    }
  }

  private var shouldInitializerBeSynthesized: Bool {
    // Don't synthesize an initializer for the special stdlib Flint$Global struct.
    guard identifier.name != Environment.globalFunctionStructName else {
      return false
    }

    let containsInitializer = members.contains { member in
      if case .initializerDeclaration(_) = member { return true }
      return false
    }

    guard !containsInitializer else { return false }

    let unassignedProperties = members.compactMap { member -> VariableDeclaration? in
      guard case .variableDeclaration(let variableDeclaration) = member,
        variableDeclaration.assignedExpression == nil else {
        return nil
      }
      return variableDeclaration
    }

    return unassignedProperties.count == 0
  }

  public init(structToken: Token, identifier: Identifier, members: [StructMember]) {
    self.structToken = structToken
    self.identifier = identifier
    self.members = members

    // Synthesize an initializer if none was defined.
    if shouldInitializerBeSynthesized {
      self.members.append(.initializerDeclaration(synthesizeInitializer()))
    }
  }

  mutating func synthesizeInitializer() -> InitializerDeclaration {
    // Synthesize the initializer.
    let dummySourceLocation = sourceLocation
    let closeBraceToken = Token(kind: .punctuation(.closeBrace), sourceLocation: dummySourceLocation)
    let closeBracketToken = Token(kind: .punctuation(.closeBracket), sourceLocation: dummySourceLocation)
    return InitializerDeclaration(initToken: Token(kind: .init, sourceLocation: dummySourceLocation), attributes: [], modifiers: [], parameters: [], closeBracketToken: closeBracketToken, body: [], closeBraceToken: closeBraceToken, scopeContext: ScopeContext())
  }
}

/// The declaration of a variable or constant, either as a state property of a local variable.
public struct VariableDeclaration: SourceEntity {
  public var declarationToken: Token?
  public var identifier: Identifier
  public var type: Type
  public var isConstant: Bool
  public var assignedExpression: Expression?

  public var sourceLocation: SourceLocation {
    if let declarationToken = declarationToken {
      return .spanning(declarationToken, to: type)
    }
    return .spanning(identifier, to: type)
  }

  public init(declarationToken: Token?, identifier: Identifier, type: Type, isConstant: Bool = false, assignedExpression: Expression? = nil) {
    self.declarationToken = declarationToken
    self.identifier = identifier
    self.type = type
    self.isConstant = isConstant
    self.assignedExpression = assignedExpression
  }
}

/// The declaration of a function.
public struct FunctionDeclaration: SourceEntity {
  public var funcToken: Token

  /// The attributes associated with the function, such as `@payable`.
  public var attributes: [Attribute]

  /// The modifiers associted with the function, such as `public` or `mutating.`
  public var modifiers: [Token]
  public var identifier: Identifier
  public var parameters: [Parameter]
  public var closeBracketToken: Token
  public var resultType: Type?
  public var body: [Statement]
  public var closeBraceToken: Token

  /// The raw type of the function's return type.
  public var rawType: Type.RawType {
    return resultType?.rawType ?? .basicType(.void)
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

  /// The first parameter which is both `implicit` and has a currency type.
  public var firstPayableValueParameter: Parameter? {
    return parameters.first { $0.isPayableValueParameter }
  }

  /// The non-implicit parameters of the function.
  public var explicitParameters: [Parameter] {
    return parameters.filter { !$0.isImplicit }
  }

  public var mutatingToken: Token {
    return modifiers.first { $0.kind == .mutating }!
  }

  public var isPublic: Bool {
    return hasModifier(kind: .public)
  }

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext? = nil

  public init(funcToken: Token, attributes: [Attribute], modifiers: [Token], identifier: Identifier, parameters: [Parameter], closeBracketToken: Token, resultType: Type?, body: [Statement], closeBraceToken: Token, scopeContext: ScopeContext? = nil) {
    self.funcToken = funcToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.resultType = resultType
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
  }

  private func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind }
  }
}

/// The declaration of an initializer.
public struct InitializerDeclaration: SourceEntity {
  public var initToken: Token

  /// The attributes associated with the function, such as `@payable`.
  public var attributes: [Attribute]

  /// The modifiers associted with the function, such as `public`.
  public var modifiers: [Token]
  public var parameters: [Parameter]
  public var closeBracketToken: Token
  public var body: [Statement]
  public var closeBraceToken: Token

  public var sourceLocation: SourceLocation {
    return initToken.sourceLocation
  }

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext? = nil

  /// The non-implicit parameters of the initializer.
  public var explicitParameters: [Parameter] {
    return asFunctionDeclaration.explicitParameters
  }

  /// A function declaration equivalent of the initializer.
  public var asFunctionDeclaration: FunctionDeclaration {
    let dummyIdentifier = Identifier(identifierToken: Token(kind: .identifier("init"), sourceLocation: initToken.sourceLocation))
    return FunctionDeclaration(funcToken: initToken, attributes: attributes, modifiers: modifiers, identifier: dummyIdentifier, parameters: parameters, closeBracketToken: closeBracketToken, resultType: nil, body: body, closeBraceToken: closeBracketToken, scopeContext: scopeContext)
  }

  public var isPublic: Bool {
    return asFunctionDeclaration.isPublic
  }

  public init(initToken: Token, attributes: [Attribute], modifiers: [Token], parameters: [Parameter], closeBracketToken: Token, body: [Statement], closeBraceToken: Token, scopeContext: ScopeContext? = nil) {
    self.initToken = initToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
  }
}

/// A function attribute, such as `@payable`.
public struct Attribute: SourceEntity {
  var kind: Kind
  var token: Token

  public var sourceLocation: SourceLocation {
    return token.sourceLocation
  }

  public init?(token: Token) {
    guard case .attribute(let attribute) = token.kind, let kind = Kind(rawValue: attribute) else { return nil }
    self.kind = kind
    self.token = token
  }

  enum Kind: String {
    case payable
  }
}

/// The parameter of a function.
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

  /// Whether the parameter is both `implicit` and has a currency type.
  public var isPayableValueParameter: Bool {
    if isImplicit, type.isCurrencyType {
      return true
    }
    return false
  }

  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: type)
  }

  public var asVariableDeclaration: VariableDeclaration {
    return VariableDeclaration(declarationToken: nil, identifier: identifier, type: type)
  }

  public init(identifier: Identifier, type: Type, implicitToken: Token?) {
    self.identifier = identifier
    self.type = type
    self.implicitToken = implicitToken
  }
}

/// A type annotation for a variable.
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

/// An identifier for a contract, struct, variable, or function.
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

/// A Flint type.
public struct Type: SourceEntity {
  /// A Flint raw type, without a source location.
  public indirect enum RawType: Equatable {
    case basicType(BasicType)
    case stdlibType(StdlibType)
    case rangeType(RawType)
    case arrayType(RawType)
    case fixedSizeArrayType(RawType, size: Int)
    case dictionaryType(key: RawType, value: RawType)
    case userDefinedType(RawTypeIdentifier)
    case inoutType(RawType)
    case any
    case errorType

    public var name: String {
      switch self {
      case .fixedSizeArrayType(let rawType, size: let size): return "\(rawType.name)[\(size)]"
      case .arrayType(let rawType): return "[\(rawType.name)]"
      case .rangeType(let rawType): return "(\(rawType.name))"
      case .basicType(let builtInType): return "\(builtInType.rawValue)"
      case .stdlibType(let type): return "\(type.rawValue)"
      case .dictionaryType(let keyType, let valueType): return "[\(keyType.name): \(valueType.name)]"
      case .userDefinedType(let identifier): return identifier
      case .inoutType(let rawType): return "$inout\(rawType.name)"
      case .any: return "Any"
      case .errorType: return "Flint$ErrorType"
      }
    }

    public var isBuiltInType: Bool {
      switch self {
      case .basicType(_), .stdlibType(_), .any, .errorType: return true
      case .arrayType(let element): return element.isBuiltInType
      case .rangeType(let element): return element.isBuiltInType
      case .fixedSizeArrayType(let element, _): return element.isBuiltInType
      case .dictionaryType(let key, let value): return key.isBuiltInType && value.isBuiltInType
      case .inoutType(let element): return element.isBuiltInType
      case .userDefinedType(_): return false
      }
    }

    public var isUserDefinedType: Bool {
      return !isBuiltInType
    }

    public var isEventType: Bool {
      return self == .basicType(.event)
    }

    /// Whether the type is a dynamic type.
    public var isDynamicType: Bool {
      if case .basicType(_) = self {
        return false
      }

      return true
    }

    /// Whether the type is compatible with the given type, i.e., if two expressions of those types can be used
    /// interchangeably.
    public func isCompatible(with otherType: Type.RawType) -> Bool {
      if self == .any || otherType == .any { return true }
      guard self != otherType else { return true }

      switch (self, otherType) {
      case (.arrayType(let e1), .arrayType(let e2)):
        return e1.isCompatible(with: e2)
      case (.fixedSizeArrayType(let e1, _), .fixedSizeArrayType(let e2, _)):
        return e1.isCompatible(with: e2)
      case (.fixedSizeArrayType(let e1, _), .arrayType(let e2)):
        return e1.isCompatible(with: e2)
      case (.dictionaryType(let key1, let value1), .dictionaryType(let key2, let value2)):
        return key1.isCompatible(with: key2) && value1.isCompatible(with: value2)
      default: return false
      }
    }
  }

  public enum BasicType: String {
    case address = "Address"
    case int = "Int"
    case string = "String"
    case void = "Void"
    case bool = "Bool"
    case event = "Event"

    var isCallerCapabilityType: Bool {
      switch self {
      case .address: return true
      default: return false
      }
    }
  }

  public enum StdlibType: String {
    case wei = "Wei"
  }

  public var rawType: RawType
  public var genericArguments = [Type]()
  public var sourceLocation: SourceLocation

  public var name: String {
    return rawType.name
  }

  var isCurrencyType: Bool {
    switch rawType {
    case .stdlibType(.wei): return true
    default: return false
    }
  }

  // Initializers for each kind of raw type.

  public init(identifier: Identifier, genericArguments: [Type] = []) {
    let name = identifier.name
    if let builtInType = BasicType(rawValue: name) {
      rawType = .basicType(builtInType)
    } else if let stdlibType = StdlibType(rawValue: name) {
      rawType = .stdlibType(stdlibType)
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

  public func isSubCapability(of parent: CallerCapability) -> Bool {
    return parent.isAny || name == parent.name
  }
}

public struct TypeState: SourceEntity {
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

  public func isSubState(of parent: TypeState) -> Bool {
    return parent.isAny || name == parent.name
  }
}

/// A Flint expression.
public indirect enum Expression: SourceEntity {
  case identifier(Identifier)
  case inoutExpression(InoutExpression)
  case binaryExpression(BinaryExpression)
  case functionCall(FunctionCall)
  case literal(Token)
  case arrayLiteral(ArrayLiteral)
  case dictionaryLiteral(DictionaryLiteral)
  case `self`(Token)
  case variableDeclaration(VariableDeclaration)
  case bracketedExpression(Expression)
  case subscriptExpression(SubscriptExpression)
  case sequence([Expression])
  case range(RangeExpression)
  case rawAssembly(String, resultType: Type.RawType?)

  public var sourceLocation: SourceLocation {
    switch self {
    case .identifier(let identifier): return identifier.sourceLocation
    case .inoutExpression(let inoutExpression): return inoutExpression.sourceLocation
    case .binaryExpression(let binaryExpression): return binaryExpression.sourceLocation
    case .functionCall(let functionCall): return functionCall.sourceLocation
    case .literal(let literal): return literal.sourceLocation
    case .arrayLiteral(let arrayLiteral): return arrayLiteral.sourceLocation
    case .dictionaryLiteral(let dictionaryLiteral): return dictionaryLiteral.sourceLocation
    case .self(let `self`): return self.sourceLocation
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.sourceLocation
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.sourceLocation
    case .subscriptExpression(let subscriptExpression): return subscriptExpression.sourceLocation
    case .range(let rangeExpression): return rangeExpression.sourceLocation
    case .sequence(let expressions): return expressions.first!.sourceLocation
    case .rawAssembly(_): fatalError()
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
      subscriptExpression.baseExpression = subscriptExpression.baseExpression.assigningEnclosingType(type: type)
      return .subscriptExpression(subscriptExpression)
    case .functionCall(var functionCall):
      functionCall.identifier.enclosingType = type
      return .functionCall(functionCall)
    default:
      return self
    }
  }

  public var enclosingType: String? {
    switch self {
    case .identifier(let identifier): return identifier.enclosingType ?? identifier.name
    case .inoutExpression(let inoutExpression): return inoutExpression.expression.enclosingType
    case .binaryExpression(let binaryExpression): return binaryExpression.lhs.enclosingType
    case .bracketedExpression(let expression): return expression.enclosingType
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.identifier.name
    case .subscriptExpression(let subscriptExpression):
      if case .identifier(let identifier) = subscriptExpression.baseExpression {
        return identifier.enclosingType
      }
      return nil
    default : return nil
    }
  }

  public var enclosingIdentifier: Identifier? {
    switch self {
    case .identifier(let identifier): return identifier
    case .inoutExpression(let inoutExpression): return inoutExpression.expression.enclosingIdentifier
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.identifier
    case .binaryExpression(let binaryExpression): return binaryExpression.lhs.enclosingIdentifier
    case .bracketedExpression(let expression): return expression.enclosingIdentifier
    case .subscriptExpression(let subscriptExpression): return subscriptExpression.baseExpression.enclosingIdentifier
    default : return nil
    }
  }

  public var isLiteral: Bool {
    switch self {
    case .literal(_), .arrayLiteral(_), .dictionaryLiteral(_): return true
    default: return false
    }
  }
}

/// A statement.
public indirect enum Statement: SourceEntity {
  case expression(Expression)
  case returnStatement(ReturnStatement)
  case ifStatement(IfStatement)
  case forStatement(ForStatement)

  public var sourceLocation: SourceLocation {
    switch self {
    case .expression(let expression): return expression.sourceLocation
    case .returnStatement(let returnStatement): return returnStatement.sourceLocation
    case .ifStatement(let ifStatement): return ifStatement.sourceLocation
    case .forStatement(let forStatement): return forStatement.sourceLocation
    }
  }
}

/// An expression passed by reference, such as `&a`.
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

/// A binary expression.
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

/// A call to a function.
public struct FunctionCall: SourceEntity {
  public var identifier: Identifier
  public var arguments: [Expression]
  public var closeBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: closeBracketToken)
  }

  public var mangledIdentifier: String? = nil

  public init(identifier: Identifier, arguments: [Expression], closeBracketToken: Token) {
    self.identifier = identifier
    self.arguments = arguments
    self.closeBracketToken = closeBracketToken
  }
}

/// An array literal, such as "[1,2,3]"
public struct ArrayLiteral: SourceEntity {
  public var openSquareBracketToken: Token
  public var elements: [Expression]
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, elements: [Expression], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }
}

public struct RangeExpression: SourceEntity {
  public var openSquareBracketToken: Token
  public var closeSquareBracketToken: Token

  public var initial: Expression
  public var bound: Expression
  public var op: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public var isClosed: Bool {
    return op.kind == .punctuation(.closedRange)
  }

  public init(startToken: Token, endToken: Token, initial: Expression, bound: Expression, op: Token){
    self.openSquareBracketToken = startToken
    self.closeSquareBracketToken = endToken
    self.initial = initial
    self.bound = bound
    self.op = op
  }
}

/// A dictionary literal, such as "[1: 2, 3: 4]"
public struct DictionaryLiteral: SourceEntity {
  public var openSquareBracketToken: Token
  public var elements: [Entry]
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, elements: [Entry], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }

  public struct Entry: Equatable {
    var key: Expression
    var value: Expression

    public init(key: Expression, value: Expression) {
      self.key = key
      self.value = value
    }
  }
}

/// A subscript expression such as `a[2]`.
public struct SubscriptExpression: SourceEntity {
  public var baseExpression: Expression
  public var indexExpression: Expression
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(baseExpression, to: closeSquareBracketToken)
  }

  public init(baseExpression: Expression, indexExpression: Expression, closeSquareBracketToken: Token) {
    self.baseExpression = baseExpression
    self.indexExpression = indexExpression
    self.closeSquareBracketToken = closeSquareBracketToken
  }
}

/// A return statement.
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

/// An if statement.
public struct IfStatement: SourceEntity {
  public var ifToken: Token
  public var condition: Expression

  /// The statements in the body of the if block.
  public var body: [Statement]

  /// the statements in the body of the else block.
  public var elseBody: [Statement]

  public var sourceLocation: SourceLocation {
    return .spanning(ifToken, to: condition)
  }

  // Contextual information for the scope defined by the if body.
  public var ifBodyScopeContext: ScopeContext? = nil

  // Contextual information for the scope defined by the else body.
  public var elseBodyScopeContext: ScopeContext? = nil

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

/// A for statement.
public struct ForStatement: SourceEntity {
  public var forToken: Token
  public var variable: VariableDeclaration
  public var iterable: Expression

  /// The statements in the body of the for block.
  public var body: [Statement]

  public var sourceLocation: SourceLocation {
    return .spanning(forToken, to: iterable)
  }

  // Contextual information for the scope defined by the for body.
  public var forBodyScopeContext: ScopeContext? = nil

  public var endsWithReturnStatement: Bool {
    return body.contains { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    }
  }

  public init(forToken: Token, variable: VariableDeclaration, iterable: Expression, statements: [Statement]) {
    self.forToken = forToken
    self.variable = variable
    self.iterable = iterable
    self.body = statements
  }
}
