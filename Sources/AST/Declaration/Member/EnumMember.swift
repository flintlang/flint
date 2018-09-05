//
//  EnumMember.swift
//  AST
//
//  Created by Hails, Daniel R on 28/08/2018.
//

import Source
import Lexer

public struct EnumMember: ASTNode {
  public var caseToken: Token
  public var identifier: Identifier
  public var type: Type

  public var hiddenValue: Expression?
  public var hiddenType: Type

  public init(caseToken: Token, identifier: Identifier, type: Type, hiddenValue: Expression?, hiddenType: Type){
    self.caseToken = caseToken
    self.identifier = identifier
    self.hiddenValue = hiddenValue
    self.type = type
    self.hiddenType = hiddenType
  }

  // MARK: - ASTNode
  public var description: String {
    return "case \(identifier)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(caseToken, to: identifier)
  }
}
