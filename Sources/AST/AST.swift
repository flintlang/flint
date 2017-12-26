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

public struct ContractDeclaration {
  public var identifier: Identifier
  public var variableDeclarations: [VariableDeclaration]

  public init(identifier: Identifier, variableDeclarations: [VariableDeclaration]) {
    self.identifier = identifier
    self.variableDeclarations = variableDeclarations
  }
}

public struct ContractBehaviorDeclaration {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]
  public var functionDeclarations: [FunctionDeclaration]

  public init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability], functionDeclarations: [FunctionDeclaration]) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
    self.functionDeclarations = functionDeclarations
  }
}

public struct VariableDeclaration {
  public var identifier: Identifier
  public var type: Type

  public init(identifier: Identifier, type: Type) {
    self.identifier = identifier
    self.type = type
  }
}

public struct FunctionDeclaration {
  public var modifiers: [Token]
  public var identifier: Identifier
  public var parameters: [Parameter]
  public var resultType: Type?
  
  public var body: [Statement]

  public init(modifiers: [Token], identifier: Identifier, parameters: [Parameter], resultType: Type?, body: [Statement]) {
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.resultType = resultType
    self.body = body
  }

  public func mangled(inContract contract: Identifier, withCallerCapabilities callerCapabilities: [CallerCapability]) -> MangledFunction {
    return MangledFunction(contractIdentifier: contract, callerCapabilities: callerCapabilities, functionDeclaration: self)
  }
}

public struct Parameter {
  public var identifier: Identifier
  public var type: Type

  public init(identifier: Identifier, type: Type) {
    self.identifier = identifier
    self.type = type
  }
}

public struct TypeAnnotation {
  public var type: Type

  public init(type: Type) {
    self.type = type
  }
}

public struct Identifier {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}

public struct Type {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}

public struct CallerCapability {
  public var name: String

  public init(name: String) {
    self.name = name
  }

  public func isSubcapability(callerCapability: CallerCapability) -> Bool {
    return name == callerCapability.name || callerCapability.name == "any"
  }
}

public indirect enum Expression {
  case identifier(Identifier)
  case binaryExpression(BinaryExpression)
  case functionCall(FunctionCall)
  case literal(Token.Literal)
  case variableDeclaration(VariableDeclaration)
  case bracketedExpression(Expression)
}

public indirect enum Statement {
  case expression(Expression)
  case returnStatement(ReturnStatement)
  case ifStatement(IfStatement)
}

public struct BinaryExpression {
  public var lhs: Expression
  public var op: Token.BinaryOperator
  public var rhs: Expression

  public init(lhs: Expression, op: Token.BinaryOperator, rhs: Expression) {
    self.lhs = lhs
    self.op = op
    self.rhs = rhs
  }
}

public struct FunctionCall {
  public var identifier: Identifier
  public var arguments: [Expression]

  public init(identifier: Identifier, arguments: [Expression]) {
    self.identifier = identifier
    self.arguments = arguments
  }
}

public struct ReturnStatement {
  public var expression: Expression?

  public init(expression: Expression?) {
    self.expression = expression
  }
}

public struct IfStatement {
  public var condition: Expression
  public var statements: [Statement]
  public var elseClauseStatements: [Statement]

  public init(condition: Expression, statements: [Statement], elseClauseStatements: [Statement]) {
    self.condition = condition
    self.statements = statements
    self.elseClauseStatements = elseClauseStatements
  }
}
