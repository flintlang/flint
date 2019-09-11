//
//  Expression.swift
//  YUL
//
//

public indirect enum Expression: CustomStringConvertible, Throwing {
  case functionCall(FunctionCall)
  case structConstructor(StructConstructor)
  case identifier(Identifier)
  case transfer(Transfer)
  case literal(Literal)
  case catchable(value: Expression, success: Expression)

  // TODO: these three should really be statements
  case variableDeclaration(VariableDeclaration)
  case fieldDeclaration(FieldDeclaration)
  case assignment(Assignment)
  case noop

  case operation(Operation)
  case inline(String)

  public var catchableSuccesses: [Expression] {
    switch self {
    case .variableDeclaration(let decl):
      return decl.catchableSuccesses
    case .fieldDeclaration(let decl):
      return decl.catchableSuccesses
    case .assignment(let assign):
      return assign.catchableSuccesses
    case .functionCall(let f):
      return f.catchableSuccesses
    case .catchable(_, let success):
      return [success]
    case .structConstructor(let c):
      return c.catchableSuccesses
    default:
      return []
    }
  }

  public var description: String {
    switch self {
    case .functionCall(let call):
      return call.description
    case .structConstructor(let constructor):
      return constructor.description
    case .identifier(let id):
      return id
    case .literal(let l):
      return l.description
    case .variableDeclaration(let decl):
      return decl.description
    case .fieldDeclaration(let decl):
        return decl.description
    case .catchable(let value, _):
      return value.description
    case .noop:
      return ""
    case .inline(let s):
      return s
    case .operation(let operation):
      return operation.description
    case .assignment(let assign):
      return assign.description
    case .transfer(let transfer):
      return transfer.description
    }
  }

  public var kindName: String {
    switch self {
    case .functionCall: return "functionCall"
    case .identifier: return "identifier"
    case .literal: return "literal"
    case .operation: return "operation"
    case .noop: return "noop"
    case .variableDeclaration: return "variableDeclaration"
    case .fieldDeclaration: return "fieldDeclaration"
    case .assignment: return "assignment"
    case .inline: return "inline"
    case .catchable: return "catchable"
    case .structConstructor: return "structConstructor"
    case .transfer: return "transfer"
    }
  }
}
