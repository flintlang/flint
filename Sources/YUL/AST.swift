//
//  AST.swift
//  YUL
//
//  Created by Yicheng Luo on 11/16/18.
//

import Foundation

public typealias Identifier = String

public enum Literal: CustomStringConvertible {
  case num(Int)
  case string_(String)
  case bool_(Bool)
  case decimal((n1: Int, n2: Int))
  case hex(String)

  public var description: String {
    switch self {
    case .num(let i):
      return String(i)
    case .string_(let s):
      return "\"\(s)\""
    case .bool_(let b):
      return b ? "1" : "0"
    case .decimal(let (n1, n2)):
      return "\(n1).\(n2)"
    case .hex(let h):
      return h
    }
  }
}

public struct Block: CustomStringConvertible {
  public var statements: [Statement]

  public init(_ statements: [Statement]) {
    self.statements = statements
  }

  public var description: String {
    let statement_description = self.statements.map({ s in
      return s.description
    }).joined(separator: "\n")

    return """
    {
      \(statement_description)
    }
    """
  }

}

public struct If: CustomStringConvertible {
  public let expression: Expression
  public let block: Block

  public init(_ expression: Expression, _ block: Block) {
    self.expression = expression
    self.block = block
  }

  public var description: String {
    return "if \(expression.description) \(self.block)"
  }
}


public struct Switch: CustomStringConvertible {
  public let expression: Expression
  public let cases: [(Literal, Block)]
  public let default_: Block?

  public init(_ expression: Expression, cases: [(Literal, Block)], default_: Block? = nil) {
    self.expression = expression
    self.cases = cases
    self.default_ = default_
  }

  public var description: String {
    let cases = self.cases.map { (lit, block) in
      return "case \(lit) \(block)"
      }.joined(separator: "\n")

    let default_ = self.default_ != nil ? "default \(self.default_!)" : ""

    return """
    switch \(self.expression)
    \(cases)
    \(default_)
    """

  }

}

public struct ForLoop: CustomStringConvertible {
  public let initialize: Block
  public let condition: Expression
  public let step: Block
  public let body: Block

  public init(_ initialize: Block, _ condition: Expression, _ step: Block, _ body: Block) {
    self.initialize = initialize
    self.condition = condition
    self.step = step
    self.body = body
  }

  public var description: String {
    return "for \(initialize) \(condition) \(step) \(body)"
  }
}


public enum Statement: CustomStringConvertible {
  case block(Block)
  case functionDefinition(FunctionDefinition)
  case variableDeclaration(VariableDeclaration)
  case assignment(Assignment)
  case if_(If)
  case expression(Expression)
  case switch_(Switch)
  case forloop(ForLoop)
  case break_
  case continue_
  case noop
  case inline(String)

  public var description: String {
    switch self {
    case .block(let b):
      return b.description
    case .functionDefinition(let f):
      return f.description
    case .variableDeclaration(let decl):
      return decl.description
    case .assignment(let assign):
      return assign.description
    case .if_(let ifs):
      return ifs.description
    case .expression(let e):
      return e.description
    case .switch_(let sw):
      return sw.description
    case .forloop(let loop):
      return loop.description
    case .break_:
      return "break"
    case .continue_:
      return "continue"
    case .noop:
      return ""
    case .inline(let s):
      return s
    }
  }
}

public enum Ty: CustomStringConvertible {
  case BOOL
  case U8
  case S8
  case U32
  case S32
  case U64
  case S64
  case U128
  case S128
  case U256
  case S256

  public var description: String {
    switch self {
    case .BOOL:
      return "bool"
    case .U8:
      return "u8"
    case .S8:
      return "s8"
    case .U32:
      return "u32"
    case .S32:
      return "s32"
    case .U64:
      return "u64"
    case .S64:
      return "s64"
    case .U128:
      return "u128"
    case .S128:
      return "s128"
    case .U256:
      return "u256"
    case .S256:
      return "s256"
    }
  }
}

public struct FunctionDefinition: CustomStringConvertible {
  public let identifier: Identifier
  public let arguments: [(Identifier, Ty)]

  public init(identifier: Identifier, arguments:  [(Identifier, Ty)]) {
    self.identifier = identifier
    self.arguments = arguments
  }

  public var description: String {
    let args = arguments.map({ (ident, ty) in
      return "\(ident): \(ty)"
    }).joined(separator: ", ")
    return "\(self.identifier)(\(args))"
  }
}

public struct VariableDeclaration: CustomStringConvertible {
  public let declarations: [(Identifier, Ty)]
  public init(declarations: [(Identifier, Ty)]) {
    self.declarations = declarations
  }

  public var description: String {
    let decls = self.declarations.map({ (ident, ty) in
      return "\(ident): \(ty)"
    }).joined(separator: ", ")
    return "let \(decls)"
  }
}

public struct Assignment: CustomStringConvertible {
  public let identifiers: [Identifier]
  public let expression: Expression

  public init(_ identifiers: [Identifier], _ rhs: Expression) {
    self.identifiers = identifiers
    self.expression = rhs
  }

  public var description: String {
    let lhs = self.identifiers.joined(separator: ", ")
    return "\(lhs) := \(self.expression)"
  }
}

public enum Expression: CustomStringConvertible {
  case functionCall(FunctionCall)
  case identifier(Identifier)
  case literal(Literal)
  case inline(String)

  public var description: String {
    switch self {
    case .functionCall(let call):
      return call.description
    case .identifier(let id):
      return id
    case .literal(let l):
      return l.description
    case .inline(let s):
      return s
    }
  }
}


public struct FunctionCall: CustomStringConvertible {
  public let name: Identifier
  public let arguments: [Expression]

  public init(_ name: Identifier, _ arguments: [Expression]) {
    self.name = name
    self.arguments = arguments
  }

  public var description: String {
    let args = arguments.map({ arg in
      return arg.description
    }).joined(separator: ", ")
    return "\(name)(\(args))"
  }

}
