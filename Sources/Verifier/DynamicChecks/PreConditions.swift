import AST
import Lexer

public class PreConditionPreprocessor: ASTPass {

  // Insert assertions at the beginning of function bodies
  // for public functions with pre-conditions

  private var inContract: Bool = false
  private let checkAllFunctions: Bool

  public init(checkAllFunctions: Bool) {
    self.checkAllFunctions = checkAllFunctions
  }

  public func process(contractDeclaration: ContractDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    inContract = true
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    inContract = false
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    if self.checkAllFunctions || (self.inContract && functionDeclaration.isPublic) {
      let checks: [Statement] = functionDeclaration
          .signature
          .prePostConditions
          .filter({ $0.isPre() })
          .map({ $0.lift })
          .map({
            Statement.expression(Expression.functionCall(
                FunctionCall(identifier: Identifier(name: "assert",
                                                    sourceLocation: $0.sourceLocation),
                             arguments: [FunctionArgument(identifier: nil,
                                                          expression: $0)],
                             closeBracketToken: Token.DUMMY,
                             isAttempted: false)))
          })

      let withChecks = FunctionDeclaration(signature: functionDeclaration.signature,
                                           body: checks + functionDeclaration.body,
                                           closeBraceToken: functionDeclaration.closeBraceToken,
                                           scopeContext: functionDeclaration.scopeContext,
                                           isExternal: functionDeclaration.isExternal)

      return ASTPassResult(element: withChecks, diagnostics: [], passContext: passContext)
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    if self.checkAllFunctions || (self.inContract && specialDeclaration.isPublic) {
      let checks: [Statement] = specialDeclaration
          .signature
          .prePostConditions
          .filter { $0.isPre() }
          .map { $0.lift }
          .map {
            Statement.expression(
                Expression.functionCall(
                    FunctionCall(identifier: Identifier(name: "assert",
                                                        sourceLocation: $0.sourceLocation),
                                 arguments: [FunctionArgument(identifier: nil,
                                                              expression: $0)],
                                 closeBracketToken: Token.DUMMY,
                                 isAttempted: false)))
          }

      let withChecks = SpecialDeclaration(signature: specialDeclaration.signature,
                                          body: checks + specialDeclaration.body,
                                          closeBraceToken: specialDeclaration.closeBraceToken,
                                          scopeContext: specialDeclaration.scopeContext)

      return ASTPassResult(element: withChecks, diagnostics: [], passContext: passContext)
    }

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }
}
