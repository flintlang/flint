//
//  DoCatchStatement.swift
//  AST
//
//  Created by Ethan on 05/11/2018.
//
import Source
import Lexer

/// A do catch block.
public struct DoCatchStatement: ASTNode {
  public var doBody: [Statement]
  public var catchBody: [Statement]
  public var error: Expression

  public init(doBody: [Statement], catchBody: [Statement], error: Expression) {
    self.doBody = doBody
    self.catchBody = catchBody
    self.error = error
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return SourceLocation.spanning(doBody[0], to: catchBody[catchBody.count-1])
  }

  public var description: String {
    let doBodyText = doBody.map({ $0.description }).joined(separator: "\n")
    let catchBodyText = catchBody.map({ $0.description }).joined(separator: "\n")
    return "do {\(doBodyText)} catch {\(catchBodyText)}"
  }
}
