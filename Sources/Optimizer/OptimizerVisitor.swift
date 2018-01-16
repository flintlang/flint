//
//  OptimizerVisitor.swift
//  Optimizer
//
//  Created by Franklin Schrans on 1/16/18.
//

import AST

final class OptimizerVisitor {
  var context: Context

  init(context: Context) {
    self.context = context
  }

  func visit(_ topLevelModule: TopLevelModule) -> TopLevelModule {
    var topLevelModule = topLevelModule
    let declarations = topLevelModule.declarations.map(visit)
    topLevelModule.declarations = declarations
    return topLevelModule
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration) -> TopLevelDeclaration {
    switch topLevelDeclaration {
    case .contractDeclaration(let contractDeclaration):
      return .contractDeclaration(visit(contractDeclaration))
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      return .contractBehaviorDeclaration(visit(contractBehaviorDeclaration))
    }
  }

  func visit(_ contractDeclaration: ContractDeclaration) -> ContractDeclaration {
    var contractDeclaration = contractDeclaration
    let variableDeclarations = contractDeclaration.variableDeclarations.map(visit)
    contractDeclaration.variableDeclarations = variableDeclarations
    return contractDeclaration
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> ContractBehaviorDeclaration {
    var contractBehaviorDeclaration = contractBehaviorDeclaration
    contractBehaviorDeclaration.contractIdentifier = visit(contractBehaviorDeclaration.contractIdentifier)

    let callerCapabilities = contractBehaviorDeclaration.callerCapabilities.map(visit)
    contractBehaviorDeclaration.callerCapabilities = callerCapabilities

    let functionDeclarations = contractBehaviorDeclaration.functionDeclarations.map(visit)
    contractBehaviorDeclaration.functionDeclarations = functionDeclarations

    return contractBehaviorDeclaration
  }

  func visit(_ variableDeclaration: VariableDeclaration) -> VariableDeclaration {
    var variableDeclaration = variableDeclaration
    variableDeclaration.identifier = visit(variableDeclaration.identifier)
    variableDeclaration.type = visit(variableDeclaration.type)
    return variableDeclaration
  }

  func visit(_ functionDeclaration: FunctionDeclaration) -> FunctionDeclaration {
    var functionDeclaration = functionDeclaration
    functionDeclaration.identifier = visit(functionDeclaration.identifier)

    let parameters = functionDeclaration.parameters.map(visit)
    functionDeclaration.parameters = parameters

    let resultType = functionDeclaration.resultType.flatMap(visit)
    functionDeclaration.resultType = resultType

    functionDeclaration.body = visitBody(functionDeclaration.body)

    return functionDeclaration
  }

  func visit(_ parameter: Parameter) -> Parameter {
    return parameter
  }

  func visit(_ typeAnnotation: TypeAnnotation) -> TypeAnnotation {
    return typeAnnotation
  }

  func visit(_ identifier: Identifier) -> Identifier {
    return identifier
  }

  func visit(_ type: Type) -> Type {
    return type
  }

  func visit(_ callerCapability: CallerCapability) -> CallerCapability {
    return callerCapability
  }

  func visit(_ expression: Expression) -> Expression {
    switch expression {
    case .binaryExpression(let binaryExpression):
      return .binaryExpression(visit(binaryExpression))
    case .bracketedExpression(let expression):
      return .bracketedExpression(visit(expression))
    case .functionCall(let functionCall):
      return .functionCall(visit(functionCall))
    case .identifier(let identifier):
      return .identifier(visit(identifier))
    case .literal(_), .self(_):
      return expression
    case .variableDeclaration(let variableDeclaration):
      return .variableDeclaration(visit(variableDeclaration))
    case .subscriptExpression(let subscriptExpression):
      return .subscriptExpression(visit(subscriptExpression))
    }
  }

  func visitBody(_ statements: [Statement]) -> [Statement] {
    let statements = statements.map(visit)
    return statements
  }

  func visit(_ statement: Statement) -> Statement {
    switch statement {
    case .expression(let expression):
      return .expression(visit(expression))
    case .ifStatement(let ifStatement):
      return .ifStatement(visit(ifStatement))
    case .returnStatement(let returnStatement):
      return .returnStatement(visit(returnStatement))
    }
  }

  func visit(_ binaryExpression: BinaryExpression) -> BinaryExpression {
    var binaryExpression = binaryExpression

    binaryExpression.lhs = visit(binaryExpression.lhs)

    if let op = binaryExpression.opToken.operatorAssignmentOperator {
      let sourceLocation = binaryExpression.op.sourceLocation
      let token = Token(kind: .punctuation(op), sourceLocation: sourceLocation)
      binaryExpression.op = Token(kind: .punctuation(.equal), sourceLocation: sourceLocation)
      binaryExpression.rhs = .binaryExpression(BinaryExpression(lhs: binaryExpression.lhs, op: token, rhs: binaryExpression.rhs))
    } else {
      binaryExpression.rhs = visit(binaryExpression.rhs)
    }

    return binaryExpression
  }

  func visit(_ functionCall: FunctionCall) -> FunctionCall {
    var functionCall = functionCall
    let arguments = functionCall.arguments.map(visit)
    functionCall.arguments = arguments
    return functionCall
  }

  func visit(_ subscriptExpression: SubscriptExpression) -> SubscriptExpression {
    var subscriptExpression = subscriptExpression
    subscriptExpression.baseIdentifier = visit(subscriptExpression.baseIdentifier)
    subscriptExpression.indexExpression = visit(subscriptExpression.indexExpression)
    return subscriptExpression
  }

  func visit(_ returnStatement: ReturnStatement) -> ReturnStatement {
    var returnStatement = returnStatement

    if let expression = returnStatement.expression {
      returnStatement.expression = visit(expression)
    }

    return returnStatement
  }

  func visit(_ ifStatement: IfStatement) -> IfStatement {
    var ifStatement = ifStatement
    ifStatement.body = visitBody(ifStatement.body)
    return ifStatement
  }
}
