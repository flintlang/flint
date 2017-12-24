public struct TopLevelModule {
  var declarations: [TopLevelDeclaration]
}

enum TopLevelDeclaration {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
}

struct ContractDeclaration {
  var identifier: Identifier
  var variableDeclarations: [VariableDeclaration]
}

struct ContractBehaviorDeclaration {
  var contractIdentifier: Identifier
  var callerCapabilities: [CallerCapability]
  var functionDeclarations: [FunctionDeclaration]
}

struct VariableDeclaration {
  var identifier: Identifier
  var type: Type
}

struct FunctionDeclaration {
  var modifiers: [Token]
  var identifier: Identifier
  var parameters: [Parameter]
  var resultType: Type?
  
  var body: [Statement]
}

struct Parameter {
  var identifier: Identifier
  var type: Type
}

struct TypeAnnotation {
  var type: Type
}

struct Identifier {
  var name: String
}

struct Type {
  var name: String
}

struct CallerCapability {
  var name: String
}

indirect enum Expression {
  case identifier(Identifier)
  case binaryExpression(BinaryExpression)
  case functionCall(FunctionCall)
  case literal(Token.Literal)
  case variableDeclaration(VariableDeclaration)
}

indirect enum Statement {
  case expression(Expression)
  case returnStatement(ReturnStatement)
}

struct BinaryExpression {
  var lhs: Expression
  var op: Token.BinaryOperator
  var rhs: Expression
}

struct FunctionCall {
  var identifier: Identifier
  var arguments: [Expression]
}

struct ReturnStatement {
  var expression: Expression
}
