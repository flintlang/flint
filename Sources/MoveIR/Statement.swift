//
//  Statement.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public enum Statement: CustomStringConvertible, Throwing {
  case block(Block)
  case functionDefinition(FunctionDefinition)
  case `if`(If)
  case expression(Expression)
  case `switch`(Switch)
  case `for`(ForLoop)
  case `break`
  case `continue`
  case noop
  case inline(String)

  public var catchableSuccesses: [Expression] {
    switch self {
    case .if(let ifs):
      return ifs.catchableSuccesses
    case .expression(let e):
      return e.catchableSuccesses
    case .switch(let sw):
      return sw.catchableSuccesses
    default:
      return []
    }
  }

  public var description: String {
    switch self {
    case .block(let b):
      return b.description
    case .functionDefinition(let f):
      return f.description
    case .if(let ifs):
      return ifs.description
    case .expression(let e):
      return e.description
    case .switch(let sw):
      return sw.description
    case .`for`(let loop):
      return loop.description
    case .break:
      return "break"
    case .continue:
      return "continue"
    case .noop:
      return ""
    case .inline(let s):
      return s + ";"
    }
  }

  static public func renderStatements(statements: [Statement]) -> String {
    return statements.map { $0.description }.joined(separator: "\n")
  }
}
