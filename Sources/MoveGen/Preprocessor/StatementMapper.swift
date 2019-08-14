//
// Created by matthewross on 14/08/19.
//

import Foundation
import AST

protocol StatementMapping {
  func map(statement: Statement) -> [Statement]?
}

extension StatementMapping {
  func apply(_ statements: [Statement]) -> [Statement] {
    return RecursiveStatementMapper(pre: [self]).apply(statements)
  }
}

class RecursiveStatementMapper {
  let pre: [StatementMapping]
  let post: [StatementMapping]

  init(pre: [StatementMapping] = [], post: [StatementMapping] = []) {
    self.pre = pre
    self.post = post
  }

  func apply(_ statements: [Statement]) -> [Statement] {
    return statements.flatMap { (statement: Statement) -> [Statement] in
      var statements = [statement]
      for mapper: StatementMapping in pre {
        statements = statements.flatMap { mapper.map(statement: $0) ?? [$0] }
      }
      statements = statements.map { (statement: Statement) -> Statement in
        switch statement {
        case .forStatement(var stmt):
          stmt.body = apply(stmt.body)
          return .forStatement(stmt)
        case .ifStatement(var stmt):
          stmt.body = apply(stmt.body)
          return .ifStatement(stmt)
        case .doCatchStatement(var stmt):
          stmt.doBody = apply(stmt.doBody)
          stmt.catchBody = apply(stmt.catchBody)
          return .doCatchStatement(stmt)
        default:
          return statement
        }
      }
      for mapper: StatementMapping in post {
        statements = statements.flatMap { mapper.map(statement: $0) ?? [$0] }
      }
      return statements
    }
  }
}
