extension TopLevelModule: Equatable {
  public static func ==(lhs: TopLevelModule, rhs: TopLevelModule) -> Bool {
    return lhs.declarations == rhs.declarations
  }
}

extension TopLevelDeclaration: Equatable {
  public static func ==(lhs: TopLevelDeclaration, rhs: TopLevelDeclaration) -> Bool {
    switch (lhs, rhs) {
    case (.contractDeclaration(let lhsContractDeclaration), .contractDeclaration(let rhsContractDeclaration)):
      return lhsContractDeclaration == rhsContractDeclaration
    case (.contractBehaviorDeclaration(let lhsContractBehaviorDeclaration), .contractBehaviorDeclaration(let rhsContractBehaviorDeclaration)):
      return lhsContractBehaviorDeclaration == rhsContractBehaviorDeclaration
    default: return false
    }
  }
}

extension ContractDeclaration: Equatable {
  public static func ==(lhs: ContractDeclaration, rhs: ContractDeclaration) -> Bool {
    return
      lhs.identifier == rhs.identifier &&
      lhs.variableDeclarations == rhs.variableDeclarations
  }
}

extension ContractBehaviorDeclaration: Equatable {
  public static func ==(lhs: ContractBehaviorDeclaration, rhs: ContractBehaviorDeclaration) -> Bool {
    return
  lhs.contractIdentifier == rhs.contractIdentifier &&
        lhs.callerCapabilities == rhs.callerCapabilities &&
        lhs.functionDeclarations == rhs.functionDeclarations
  }
}

extension VariableDeclaration: Equatable {
  public static func ==(lhs: VariableDeclaration, rhs: VariableDeclaration) -> Bool {
    return
      lhs.identifier == rhs.identifier &&
      lhs.type == rhs.type
  }
}

extension FunctionDeclaration: Equatable {
  public static func ==(lhs: FunctionDeclaration, rhs: FunctionDeclaration) -> Bool {
    return
      lhs.modifiers == rhs.modifiers &&
      lhs.identifier == rhs.identifier &&
      lhs.parameters == rhs.parameters &&
      lhs.resultType == rhs.resultType &&
      lhs.body == rhs.body
  }
}

extension Parameter: Equatable {
  public static func ==(lhs: Parameter, rhs: Parameter) -> Bool {
    return
      lhs.identifier == rhs.identifier &&
      lhs.type == rhs.type
  }
}

extension TypeAnnotation: Equatable {
  public static func ==(lhs: TypeAnnotation, rhs: TypeAnnotation) -> Bool {
    return lhs.type == rhs.type
  }
}

extension Identifier: Equatable {
  public static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
    return lhs.name == rhs.name
  }
}

extension Type: Equatable {
  public static func ==(lhs: Type, rhs: Type) -> Bool {
    return lhs.rawType == rhs.rawType
  }
}

extension CallerCapability: Equatable {
  public static func ==(lhs: CallerCapability, rhs: CallerCapability) -> Bool {
    return lhs.name == rhs.name
  }
}

extension BinaryExpression: Equatable {
  public static func ==(lhs: BinaryExpression, rhs: BinaryExpression) -> Bool {
    return
      lhs.lhs == rhs.lhs &&
      lhs.rhs == rhs.rhs &&
      lhs.op == rhs.op
  }
}

extension FunctionCall: Equatable {
  public static func ==(lhs: FunctionCall, rhs: FunctionCall) -> Bool {
    return
      lhs.identifier == rhs.identifier &&
      lhs.arguments == rhs.arguments
  }
}

extension Expression: Equatable {
  public static func ==(lhs: Expression, rhs: Expression) -> Bool {
    switch (lhs, rhs) {
    case (.identifier(let lhsIdentifier), .identifier(let rhsIdentifier)):
      return lhsIdentifier == rhsIdentifier
    case (.binaryExpression(let lhsBinaryExpression), .binaryExpression(let rhsBinaryExpression)):
      return lhsBinaryExpression == rhsBinaryExpression
    case (.functionCall(let lhsFunctionCall), .functionCall(let rhsFunctionCall)):
      return lhsFunctionCall == rhsFunctionCall
    case (.literal(let lhsLiteral), .literal(let rhsLiteral)):
      return lhsLiteral == rhsLiteral
    case (.variableDeclaration(let lhsVariableDeclaration), .variableDeclaration(let rhsVariableDeclaration)):
      return lhsVariableDeclaration == rhsVariableDeclaration
    case (.bracketedExpression(let lhsExpression), .bracketedExpression(let rhsExpression)):
      return lhsExpression == rhsExpression
    default:
      return false
    }
  }
}

extension Statement: Equatable {
  public static func ==(lhs: Statement, rhs: Statement) -> Bool {
    switch (lhs, rhs) {
    case (.expression(let lhsExpression), .expression(let rhsExpression)):
      return lhsExpression == rhsExpression
    case (.returnStatement(let lhsReturnStatement), .returnStatement(let rhsReturnStatement)):
      return lhsReturnStatement == rhsReturnStatement
    case (.ifStatement(let lhsIfStatement), .ifStatement(let rhsIfStatement)):
      return lhsIfStatement == rhsIfStatement
    default:
      return false
    }
  }
}

extension ReturnStatement: Equatable {
  public static func ==(lhs: ReturnStatement, rhs: ReturnStatement) -> Bool {
    return lhs.expression == rhs.expression
  }
}

extension IfStatement: Equatable {
  public static func ==(lhs: IfStatement, rhs: IfStatement) -> Bool {
    return
      lhs.condition == rhs.condition &&
      lhs.statements == rhs.statements &&
      lhs.elseClauseStatements == rhs.elseClauseStatements
  }
}

