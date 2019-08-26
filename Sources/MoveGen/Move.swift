//
// Created by matthewross on 2/08/19.
//

import Foundation
import AST
import Lexer

enum Move {
  public static let statementSeparator = ";"
  public static let statementLineSeparator = ";\n"

  public static func release(expression: AST.Expression, passContext: ASTPassContext) -> AST.Statement {
    guard let environment = passContext.environment,
          let scopeContext = passContext.scopeContext,
          let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      fatalError("Cannot release expression of unknowable type")
    }
    let type = environment.type(
        of: expression,
        enclosingType: enclosingType,
        typeStates: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
        callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? [],
        scopeContext: scopeContext
    )
    return release(expression: expression, type: type)
  }

  public static func release(expression: AST.Expression, type: RawType) -> AST.Statement {
    return .expression(.binaryExpression(BinaryExpression(
        lhs: .rawAssembly("_", resultType: type),
        op: Token(kind: .punctuation(.equal), sourceLocation: expression.sourceLocation),
        rhs: expression)
    ))
  }
}

enum Position {
  case left, accessed, normal, inOut
}
