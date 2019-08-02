import AST
import Diagnostic
import Lexer
import Source

public class ConstructorPreProcessor: ASTPass {

  // Get all variable declarations, extract expression assignments (if any)
  // Add expression assignments to contract constructor

  private var assignedStatements: [String: [Statement]] = [:]

  public init() {}

  public func process(contractDeclaration: ContractDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    for variable in contractDeclaration.variableDeclarations {
      if let expression = variable.assignedExpression {
        addAssignedExpression(tld: contractDeclaration.identifier.name,
                              statement: makeSelfAssignment(variable, expression))
      }
    }

    let noAssignments: [ContractMember] = contractDeclaration.members.compactMap({
      if case .variableDeclaration(let variableDeclaration) = $0 {
        let noAssignment = VariableDeclaration(modifiers: variableDeclaration.modifiers,
                                               declarationToken: variableDeclaration.declarationToken,
                                               identifier: variableDeclaration.identifier,
                                               type: variableDeclaration.type,
                                               assignedExpression: nil)
        return .variableDeclaration(noAssignment)
      }
      return $0
    })

    let contractDeclaration = ContractDeclaration(contractToken: contractDeclaration.contractToken,
                                                  identifier: contractDeclaration.identifier,
                                                  conformances: contractDeclaration.conformances,
                                                  states: contractDeclaration.states,
                                                  members: noAssignments)

    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    for variable in structDeclaration.variableDeclarations {
      if let expression = variable.assignedExpression {
        addAssignedExpression(tld: structDeclaration.identifier.name,
                              statement: makeSelfAssignment(variable, expression))
      }
    }

    let noAssignments: [StructMember] = structDeclaration.members.compactMap({
      if case .variableDeclaration(let variableDeclaration) = $0 {
        let noAssignment = VariableDeclaration(modifiers: variableDeclaration.modifiers,
                                               declarationToken: variableDeclaration.declarationToken,
                                               identifier: variableDeclaration.identifier,
                                               type: variableDeclaration.type,
                                               assignedExpression: nil)
        return .variableDeclaration(noAssignment)
      }
      return $0
    })

    let structDeclaration = StructDeclaration(structToken: structDeclaration.structToken,
                                              identifier: structDeclaration.identifier,
                                              conformances: structDeclaration.conformances,
                                              members: noAssignments)

    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    if specialDeclaration.isInit {
      guard let tld = passContext.enclosingTypeIdentifier?.name else {
        print("Could not determine TLD for initialiser")
        fatalError()
      }

      let updatedDecl = SpecialDeclaration(signature: specialDeclaration.signature,
                                           body: (self.assignedStatements[tld] ?? []) + specialDeclaration.body,
                                           closeBraceToken: specialDeclaration.closeBraceToken,
                                           scopeContext: specialDeclaration.scopeContext,
                                           generated: specialDeclaration.generated)

      return ASTPassResult(element: updatedDecl, diagnostics: [], passContext: passContext)
    }

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  private func addAssignedExpression(tld: String, statement: Statement) {
    var statements = [Statement]()
    if let es = self.assignedStatements[tld] {
      statements = es
    }

    statements.append(statement)
    self.assignedStatements[tld] = statements
  }

  private func makeSelfAssignment(_ variable: VariableDeclaration, _ expression: Expression) -> Statement {
    let selfToken = Token(kind: .`self`, sourceLocation: SourceLocation.DUMMY)
    let dotToken = Token(kind: .punctuation(.dot), sourceLocation: SourceLocation.DUMMY)
    let equalToken = Token(kind: .punctuation(.equal), sourceLocation: SourceLocation.DUMMY)
    let dotExpr = BinaryExpression(lhs: .`self`(selfToken), op: dotToken, rhs: .identifier(variable.identifier))
    let assignment = BinaryExpression(lhs: .binaryExpression(dotExpr), op: equalToken, rhs: expression)
    return .expression(.binaryExpression(assignment))
  }
}
