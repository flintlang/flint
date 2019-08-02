import AST
import Lexer

public class AssertPreprocessor: ASTPass {

  // Remove assert checks from AST - as they have been verified + shown to be true

  public init() {}

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {

  let updated = FunctionDeclaration(signature: functionDeclaration.signature,
                                    body: removeAsserts(statements: functionDeclaration.body),
                                    closeBraceToken: functionDeclaration.closeBraceToken,
                                    scopeContext: functionDeclaration.scopeContext,
                                    isExternal: functionDeclaration.isExternal)

    return ASTPassResult(element: updated, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {

  let updated = SpecialDeclaration(signature: specialDeclaration.signature,
                                    body: removeAsserts(statements: specialDeclaration.body),
                                    closeBraceToken: specialDeclaration.closeBraceToken,
                                    scopeContext: specialDeclaration.scopeContext,
                                    generated: specialDeclaration.generated)

    return ASTPassResult(element: updated, diagnostics: [], passContext: passContext)
  }

  public func process(ifStatement: IfStatement,
                      passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    let updated = IfStatement(ifToken: ifStatement.ifToken,
                              condition: ifStatement.condition,
                              statements: removeAsserts(statements: ifStatement.body),
                              elseClauseStatements: removeAsserts(statements: ifStatement.elseBody))

    return ASTPassResult(element: updated, diagnostics: [], passContext: passContext)
  }

  public func process(forStatement: ForStatement,
                      passContext: ASTPassContext) -> ASTPassResult<ForStatement> {

   let updated = ForStatement(forToken: forStatement.forToken,
                              variable: forStatement.variable,
                              iterable: forStatement.iterable,
                              statements: removeAsserts(statements: forStatement.body))

    return ASTPassResult(element: updated, diagnostics: [], passContext: passContext)
  }

  public func process(doCatchStatement: DoCatchStatement,
                      passContext: ASTPassContext) -> ASTPassResult<DoCatchStatement> {

    let updated = DoCatchStatement(doBody: removeAsserts(statements: doCatchStatement.doBody),
                                   catchBody: removeAsserts(statements: doCatchStatement.catchBody),
                                   error: doCatchStatement.error,
                                   startToken: doCatchStatement.startToken,
                                   endToken: doCatchStatement.endToken)

    return ASTPassResult(element: updated, diagnostics: [], passContext: passContext)
  }

  private func removeAsserts(statements: [Statement]) -> [Statement] {
    return statements.filter({ statement in
                                 if case .expression(let e) = statement,
                                    case .functionCall(let fCall) = e,
                                      fCall.identifier.name == "assert" {
                                    return false
                                 }
                                 return true
                               })
  }
}
