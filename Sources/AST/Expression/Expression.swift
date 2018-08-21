//
//  Expression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

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
  case bracketedExpression(BracketedExpression)
  case subscriptExpression(SubscriptExpression)
  case sequence([Expression])
  case range(RangeExpression)
  case rawAssembly(String, resultType: RawType?)

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
    case .bracketedExpression(var bracketedExpression):
      bracketedExpression.expression = bracketedExpression.expression.assigningEnclosingType(type: type)
      return .bracketedExpression(bracketedExpression)
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
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.expression.enclosingType
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
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.expression.enclosingIdentifier
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
