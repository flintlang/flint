import AST
import Diagnostic

public class Verifier: ASTPass {
  public init() {}

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }
}
