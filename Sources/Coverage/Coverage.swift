import AST
import Parser
import Lexer
import Foundation
import Utils

public class CoverageProvider {
  private var functionsCount: Int = 0
  private var branchNumberCount: Int = 0
  private var statementCount: Int = 0
  private var blockNum: Int = 0

  private var functionToLineNo: [String: Int] = [:]
  private var statememtDict: [String: Int] = [:]
  private var functionDict: [String: Int] = [:]
  private var branchDict: [String: [String: Int]] = [:]

  public init() {
  }

  public func instrument(ast: TopLevelModule) -> TopLevelModule {
    var new_decs: [TopLevelDeclaration] = []

    for dec in ast.declarations {
      switch dec {
      case .contractDeclaration(let cdec):
        new_decs.append(.contractDeclaration(instrument_contract_dec(cdec: cdec)))
      case .contractBehaviorDeclaration(let cbdec):
        new_decs.append(.contractBehaviorDeclaration(instrument_contract_b_dec(cBdec: cbdec)))
      default:
        new_decs.append(dec)
      }
    }

    var counts: [String: Int] = [:]
    counts["functions"] = functionsCount
    counts["statements"] = statementCount
    counts["branch"] = branchNumberCount

    do {
      let data = try JSONSerialization.data(withJSONObject: statememtDict, options: [])
      let json_statement_dict = String(data: data, encoding: .utf8)!
      try json_statement_dict.write(
          to: Path.getFullUrl(path: "utils/coverage/statements.json"),
          atomically: true, encoding: .utf8)
    } catch {
      print(error)
      print("failed to write statements.json")
    }

    do {
      let json_branch_dict = String(data: try JSONSerialization.data(withJSONObject: branchDict, options: []),
                                    encoding: .utf8)!
      try json_branch_dict.write(
          to: Path.getFullUrl(path: "utils/coverage/branch.json"),
          atomically: true, encoding: .utf8)
    } catch let e {
      print(e)
      print("failed to write branch.json")
    }

    do {
      let json_function_dict = String(data: try JSONSerialization.data(withJSONObject: functionDict, options: []),
                                      encoding: .utf8)!
      try json_function_dict.write(
          to: Path.getFullUrl(path: "utils/coverage/function.json"),
          atomically: true, encoding: .utf8)

    } catch let e {
      print(e)
      print("failed to write function.json")
    }

    do {
      let json_function_to_line_no = String(
          data: try JSONSerialization.data(withJSONObject: functionToLineNo, options: []), encoding: .utf8)!
      try json_function_to_line_no.write(
          to: Path.getFullUrl(path: "utils/coverage/function_to_line.json"),
          atomically: true, encoding: .utf8)

    } catch let e {
      print(e)
      print("failed to write function_to_line.json")

    }

    do {
      let json = String(data: try JSONSerialization.data(withJSONObject: counts, options: []), encoding: .utf8)!
      try json.write(to: Path.getFullUrl(path: "utils/coverage/counts.json"),
                     atomically: true, encoding: .utf8)
    } catch let e {
      print(e)
      print("failed to write counts.json")
    }

    return TopLevelModule(declarations: new_decs)
  }

  private func instrument_contract_dec(cdec: ContractDeclaration) -> ContractDeclaration {

    let line = Parameter(identifier: Identifier(name: "line", sourceLocation: .DUMMY),
                         type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)), implicitToken: nil,
                         assignedExpression: nil)

    var stmVarDecs: [Parameter] = []
    stmVarDecs.append(line)
    let eventToken: Token = Token(kind: .event, sourceLocation: .DUMMY)
    let stmtEventDec: EventDeclaration = EventDeclaration(eventToken: eventToken,
                                                          identifier: Identifier(name: "stmC", sourceLocation: .DUMMY),
                                                          parameters: stmVarDecs)
    let stmtEvent: ContractMember = .eventDeclaration(stmtEventDec)

    var fncParDecs: [Parameter] = []
    fncParDecs.append(line)
    let fName = Parameter(identifier: Identifier(name: "fName", sourceLocation: .DUMMY),
                          type: Type(identifier: Identifier(name: "String", sourceLocation: .DUMMY)),
                          implicitToken: nil, assignedExpression: nil)
    fncParDecs.append(fName)
    let fncEventDec: EventDeclaration = EventDeclaration(eventToken: eventToken,
                                                         identifier: Identifier(name: "funcC", sourceLocation: .DUMMY),
                                                         parameters: fncParDecs)
    let fncEvent: ContractMember = .eventDeclaration(fncEventDec)

    var branchParDecs: [Parameter] = []
    branchParDecs.append(line)
    let branchNum = Parameter(identifier: Identifier(name: "branch", sourceLocation: .DUMMY),
                              type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)),
                              implicitToken: nil, assignedExpression: nil)
    let blockNum = Parameter(identifier: Identifier(name: "blockNum", sourceLocation: .DUMMY),
                             type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)),
                             implicitToken: nil, assignedExpression: nil)
    branchParDecs.append(branchNum)
    branchParDecs.append(blockNum)

    let branchEventDec: EventDeclaration = EventDeclaration(eventToken: eventToken,
                                                            identifier: Identifier(name: "branchC",
                                                                                   sourceLocation: .DUMMY),
                                                            parameters: branchParDecs)
    let branchEvent: ContractMember = .eventDeclaration(branchEventDec)

    var members: [ContractMember] = []

    members.append(branchEvent)
    members.append(fncEvent)
    members.append(stmtEvent)
    members.append(contentsOf: cdec.members)

    return ContractDeclaration(contractToken: cdec.contractToken, identifier: cdec.identifier,
                               conformances: cdec.conformances, states: cdec.states, members: members)
  }

  private func instrument_contract_b_dec(cBdec: ContractBehaviorDeclaration) -> ContractBehaviorDeclaration {
    var members: [ContractBehaviorMember] = []

    for mem in cBdec.members {
      switch mem {
      case .functionDeclaration(let fdec):
        members.append(.functionDeclaration(instrument_function(fDec: fdec)))
      default:
        members.append(mem)
      }
    }

    return ContractBehaviorDeclaration(contractIdentifier: cBdec.contractIdentifier, states: cBdec.states,
                                       callerBinding: cBdec.callerBinding, callerProtections: cBdec.callerProtections,
                                       closeBracketToken: cBdec.closeBracketToken, members: members)
  }

  private func func_event(line: Int, fName: String) -> Statement {
    var funcArgs: [FunctionArgument] = []
    let expr: Expression = .literal(Token(kind: .literal(.decimal(.integer(line))), sourceLocation: .DUMMY))
    let fncArg = FunctionArgument(identifier: Identifier(name: "line", sourceLocation: .DUMMY), expression: expr)

    let fncArgName = FunctionArgument(identifier: Identifier(name: "fName", sourceLocation: .DUMMY),
                                      expression: .literal(Token(kind: .literal(.string(fName)), sourceLocation: .DUMMY)
                                      ))

    funcArgs.append(fncArg)
    funcArgs.append(fncArgName)

    let emitFncStmt: Statement = .emitStatement(EmitStatement(emitToken: Token(kind: .emit, sourceLocation: .DUMMY),
                                                              functionCall: FunctionCall(
                                                                  identifier: Identifier(name: "funcC",
                                                                                         sourceLocation: .DUMMY),
                                                                  arguments: funcArgs, closeBracketToken: Token(
                                                                  kind: .punctuation(.closeBracket),
                                                                  sourceLocation: .DUMMY), isAttempted: false)))

    return emitFncStmt
  }

  private func branch_event(line: Int, branch: Int, blockNum: Int) -> Statement {
    var funcArgs: [FunctionArgument] = []

    let lineArg = FunctionArgument(identifier: Identifier(name: "line", sourceLocation: .DUMMY), expression: .literal(
        Token(kind: .literal(.decimal(.integer(line))), sourceLocation: .DUMMY)))

    let branchArg = FunctionArgument(identifier: Identifier(name: "branch", sourceLocation: .DUMMY),
                                     expression: .literal(
                                         Token(kind: .literal(.decimal(.integer(branch))), sourceLocation: .DUMMY)))

    let blockArg = FunctionArgument(identifier: Identifier(name: "blockNum", sourceLocation: .DUMMY),
                                    expression: .literal(
                                        Token(kind: .literal(.decimal(.integer(blockNum))), sourceLocation: .DUMMY)))

    funcArgs.append(lineArg)
    funcArgs.append(branchArg)
    funcArgs.append(blockArg)

    let branchEventStmt: Statement = .emitStatement(EmitStatement(emitToken: Token(kind: .emit, sourceLocation: .DUMMY),
                                                                  functionCall: FunctionCall(
                                                                      identifier: Identifier(name: "branchC",
                                                                                             sourceLocation: .DUMMY),
                                                                      arguments: funcArgs, closeBracketToken: Token(
                                                                      kind: .punctuation(.closeBracket),
                                                                      sourceLocation: .DUMMY), isAttempted: false)))

    return branchEventStmt
  }

  private func stmt_event(line: Int) -> Statement {
    var funcArgs: [FunctionArgument] = []
    let expr: Expression = .literal(Token(kind: .literal(.decimal(.integer(line))), sourceLocation: .DUMMY))
    let lineArg = FunctionArgument(identifier: Identifier(name: "line", sourceLocation: .DUMMY), expression: expr)

    funcArgs.append(lineArg)

    let stmtEventStmt: Statement =
        .emitStatement(
            EmitStatement(
                emitToken: Token(kind: .emit, sourceLocation: .DUMMY),
                functionCall: FunctionCall(identifier: Identifier(name: "stmC", sourceLocation: .DUMMY),
                                           arguments: funcArgs,
                                           closeBracketToken: Token(kind: .punctuation(.closeBracket),
                                                                    sourceLocation: .DUMMY), isAttempted: false)))

    return stmtEventStmt
  }

  private func addToBranchDict(line: Int, blockNum: Int, branchNum: Int) {
    var innerDict: [String: Int] = [:]
    innerDict["line"] = line
    innerDict["blockNum"] = blockNum
    innerDict["branchNum"] = branchNum
    innerDict["count"] = 0

    self.branchDict[line.description] = innerDict
  }

  private func instrument_if(ifS: IfStatement) -> IfStatement {
    self.branchNumberCount += 2

    var ifBody: [Statement] = []

    self.blockNum += 1
    ifBody.append(branch_event(line: ifS.ifToken.sourceLocation.line, branch: 0, blockNum: self.blockNum))
    addToBranchDict(line: ifS.sourceLocation.line, blockNum: self.blockNum, branchNum: 0)
    if !ifS.body.isEmpty {
      ifBody.append(contentsOf: intstrument_statements(stmts: ifS.body))
    }

    var elseBody: [Statement] = []
    self.blockNum += 1

    if !ifS.elseBody.isEmpty {
      elseBody.append(branch_event(line: ifS.elseBody[0].sourceLocation.line - 1, branch: 1, blockNum: self.blockNum))
      elseBody.append(contentsOf: intstrument_statements(stmts: ifS.elseBody))
      addToBranchDict(line: (ifS.elseBody[0].sourceLocation.line - 1), blockNum: self.blockNum, branchNum: 1)

    } else {
      if ifS.body.isEmpty {
        elseBody.append(branch_event(line: ifS.ifToken.sourceLocation.line + 2, branch: 1, blockNum: self.blockNum))
        addToBranchDict(line: ifS.ifToken.sourceLocation.line + 2, blockNum: self.blockNum, branchNum: 1)
      } else {
        elseBody.append(
            branch_event(line: ifS.body[ifS.body.count - 1].sourceLocation.line + 1, branch: 1, blockNum: self.blockNum)
        )
        addToBranchDict(
            line: ifS.body[ifS.body.count - 1].sourceLocation.line + 1,
            blockNum: self.blockNum,
            branchNum: 1)
      }
    }

    var ifStmt: IfStatement = IfStatement(ifToken: ifS.ifToken, condition: ifS.condition, statements: ifBody,
                                          elseClauseStatements: elseBody)

    ifStmt.ifBodyScopeContext = ifS.ifBodyScopeContext
    ifStmt.elseBodyScopeContext = ifS.elseBodyScopeContext

    return ifStmt
  }

  private func checkIfForOrIf(stmt: Statement) -> Bool {
    switch stmt {
    case .forStatement:
      return true
    case .ifStatement:
      return true
    default:
      return false
    }
  }

  private func intstrument_statements(stmts: [Statement]) -> [Statement] {
    var body: [Statement] = []

    for (i, stmt) in stmts.enumerated() {
      switch stmt {
      case .forStatement(let forStmt):
        body.append(.forStatement(instrument_for(forS: forStmt)))
      case .ifStatement(let ifStmt):
        body.append(.ifStatement(instrument_if(ifS: ifStmt)))
      case .doCatchStatement(let doCatch):
        print(doCatch)
      default:
        if (i > 0 && checkIfForOrIf(stmt: stmts[i - 1])) {
          self.blockNum += 1
        }
        self.statementCount += 1
        body.append(stmt_event(line: stmt.sourceLocation.line))
        self.statememtDict[stmt.sourceLocation.line.description] = 0
        body.append(stmt)
      }
    }

    return body
  }

  private func instrument_for(forS: ForStatement) -> ForStatement {
    self.blockNum += 1
    self.branchNumberCount += 1
    var body: [Statement] = []
    body.append(branch_event(line: forS.forToken.sourceLocation.line, branch: 0, blockNum: self.blockNum))
    addToBranchDict(line: forS.forToken.sourceLocation.line, blockNum: self.blockNum, branchNum: 0)
    body.append(contentsOf: intstrument_statements(stmts: forS.body))

    var instForStmt = ForStatement(forToken: forS.forToken, variable: forS.variable, iterable: forS.iterable,
                                   statements: body)

    instForStmt.forBodyScopeContext = forS.forBodyScopeContext

    return instForStmt

  }

  private func instrument_function(fDec: FunctionDeclaration) -> FunctionDeclaration {
    self.functionsCount += 1
    self.blockNum += 1
    self.functionToLineNo[fDec.name] = fDec.signature.sourceLocation.line
    self.functionDict[fDec.name] = 0

    var body: [Statement] = []

    let emitFncStmt = func_event(line: fDec.sourceLocation.line, fName: fDec.identifier.name)
    body.append(emitFncStmt)

    body.append(contentsOf: intstrument_statements(stmts: fDec.body))

    return FunctionDeclaration(
        signature: fDec.signature,
        body: body,
        closeBraceToken: fDec.closeBraceToken,
        scopeContext: fDec.scopeContext,
        isExternal: fDec.isExternal)
  }

}
