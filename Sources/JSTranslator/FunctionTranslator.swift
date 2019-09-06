import AST
import Foundation
import Lexer
import Parser

public class FunctionTranslator {

  private let jst: JSTranslator
  private var varMap: [String: JSVariable] = [:]
  private let NIL_TYPE = "nil"
  private var error_array: [String] = []

  public init(jst: JSTranslator) {
    self.jst = jst
  }

  public func translate(functionDeclaration: FunctionDeclaration) -> (JSTestFunction?, [String]) {
    let jsTestFunc = processContractFunction(functionDeclaration: functionDeclaration)

    return (jsTestFunc, error_array)
  }

  private func processContractFunction(functionDeclaration: FunctionDeclaration) -> JSTestFunction? {
    let functionSignature: FunctionSignatureDeclaration = functionDeclaration.signature

    let functionName: String = functionSignature.identifier.name

    var jsStatements: [JSNode] = []

    // if this is not a test function then do not process
    if !functionName.lowercased().contains("test") {
      return nil
    }

    let body: [Statement] = functionDeclaration.body

    for statement in body {
      switch statement {
      case .expression(let expression):
        if let jsExpression = processExpression(expression: expression) {
          jsStatements.append(jsExpression)
        }

      default:
        continue
      }
    }

    return JSTestFunction(name: functionName, statements: jsStatements)
  }

  private func processExpression(expression: Expression) -> JSNode? {
    switch expression {
    case .binaryExpression(let binaryExpression):
      return processBinaryExpression(binaryExpression: binaryExpression)
    case .functionCall(let functionCall):
      return processFunctionCall(functionCall: functionCall)

    default:
      print("Expression \(expression.description) is not supported yet".lightRed.bold)
      exit(0)
    }
  }

  private func processBinaryExpression(binaryExpression: BinaryExpression) -> JSNode? {
    switch binaryExpression.opToken {
    case .equal:
      return processAssignmentExpr(binaryExpression: binaryExpression)
    case .dot:
      return processDotExpression(binaryExpression: binaryExpression)
    default:
      error_array.append(
          "Test framework does not yet support expressions with operator \(binaryExpression.description) "
              + "at \(binaryExpression.sourceLocation)".lightRed.bold
      )
      return nil
    }
  }

  private func processDotExpression(binaryExpression: BinaryExpression) -> JSNode? {
    var lhsName: String = ""
    var rhsNode: JSNode?

    switch binaryExpression.lhs {
    case .identifier(let identifier):
      lhsName = identifier.name
      guard nil != varMap[lhsName] else {
        error_array.append("Variable \(lhsName) not in scope at \(identifier.sourceLocation)")
        return nil
      }
    default:
      break
    }

    switch binaryExpression.rhs {
    case .functionCall(let functionCall):
      guard nil != jst.contractFunctionInfo[functionCall.identifier.name] else {
        // function does not exist in contract (currently support single contract deploment)
        error_array.append(
            "Function \(functionCall.identifier.name) not found in contract at \(functionCall.sourceLocation)"
              .lightRed.bold)
        return nil
      }
      rhsNode = processFunctionCall(functionCall: functionCall, lhsName: lhsName)

    case .identifier(let identifier):
      if nil == jst.contractEventInfo[identifier.name] && !jst.contractFunctionNames.contains(identifier.name) {
        error_array.append(
            "Only events and functions are supported on the rhs of dot expression at \(identifier.sourceLocation)"
              .lightRed.bold)
        return nil
      }

      rhsNode = .Variable(JSVariable(variable: "\"" + identifier.name + "\"", type: "event", isConstant: false))
    default:
      error_array.append(("Unsupported expression found on the RHS of dot expr \(binaryExpression.rhs)"
          + " at \(binaryExpression.sourceLocation)").lightRed.bold)
      return nil
    }

    return rhsNode
  }

  private func processAssignmentExpr(binaryExpression: BinaryExpression) -> JSNode? {
    var rhsNode: JSNode?
    var lhsNode: JSVariable?
    var isInstantiation: Bool = false

    switch binaryExpression.lhs {
    case .variableDeclaration(let variableDeclaration):
      let name = variableDeclaration.identifier.name
      let isConst = variableDeclaration.isConstant
      var varType = self.NIL_TYPE
      switch variableDeclaration.type.rawType {
      case .basicType(let rt):
        switch rt {
        case .string:
          varType = "String"
        case .int:
          varType = "Int"
        case .address:
          varType = "Address"
        case .bool:
          varType = "Bool"
        case .void:
          varType = self.NIL_TYPE
        case .event:
          error_array.append(
              "Error, event cannot be part of a variable declaration at \(binaryExpression.lhs.sourceLocation)"
                .lightRed.bold)
          return nil
        }
      default:
        varType = variableDeclaration.type.rawType.name
      }

      lhsNode = JSVariable(variable: name, type: varType, isConstant: isConst)
      if nil != varMap[name] {
        error_array.append("Redeclaration of variable \(name) at \(binaryExpression.lhs.sourceLocation)".lightRed.bold)
        return nil
      }

      varMap[name] = lhsNode
    case .identifier(let i):

      guard let lhsN = varMap[i.name] else {
        error_array.append("Variable \(i.name) not in scope at \(binaryExpression.sourceLocation)".lightRed.bold)
        return nil
      }

      if lhsN.isConstant() {
        error_array.append(
            "Variable \(i.name) marked as const, cannot reassign at \(binaryExpression.sourceLocation)".lightRed.bold)
        return nil
      }

      lhsNode = lhsN

    default:
      error_array.append(("Found invalid LHS in assignment expression \(binaryExpression.lhs.description) "
          + " at \(binaryExpression.sourceLocation)").lightRed.bold)
      return nil
    }

    switch binaryExpression.rhs {
    case .binaryExpression(let binaryExpression):
      rhsNode = processBinaryExpression(binaryExpression: binaryExpression)

    case .functionCall(let functionCall):
      isInstantiation = !functionCall.identifier.name.lowercased().contains("assert")
      && !jst.contractFunctionNames.contains(functionCall.identifier.name)
      && functionCall.identifier.name.lowercased().contains(jst.getContractName().lowercased())
      rhsNode = processFunctionCall(functionCall: functionCall)

    case .literal(let li):
      if let lit = extractLiteral(literalToken: li) {
        rhsNode = lit
      } else {
        error_array.append(("Could not find valid literal on the RHS of expression \(li.description)"
            + " at \(binaryExpression.rhs.sourceLocation)").lightRed.bold)
        return nil
      }
    default:
      break
    }

    guard nil != rhsNode else {
      return nil
    }

    guard nil != lhsNode else {
      return nil
    }

    if rhsNode!.getType() != lhsNode!.getType() {
      error_array.append("Mismatch of types at \(binaryExpression.sourceLocation)")
      return nil
    }

    return .VariableAssignment(JSVariableAssignment(lhs: lhsNode!, rhs: rhsNode!, isInstantiation: isInstantiation))
  }

  private func extractLiteral(literalToken: Token) -> JSNode? {
    switch literalToken.kind {
    case .literal(let lit):
      switch lit {
      case .decimal(let dec):
        switch dec {
        case .integer(let val):
          return .Literal(.Integer(val))
        default:
          break
        }
      case .address(let s):
        return .Literal(.String(s))
      case .string(let s):
        return .Literal(.String(s))
      case .boolean(let b):
        return .Literal(.Bool(b.rawValue))
      }
    default:
      return nil
    }

    return nil
  }

  private func processFuncCallArgs(args: [FunctionArgument], functionName: String = "") -> [JSNode] {

    var jsArgs: [JSNode] = []

    for (i, arg) in args.enumerated() {
      switch arg.expression {
      case .identifier(let i):
        if let jsVar = varMap[i.name] {
          jsArgs.append(.Variable(jsVar))
        } else {
          error_array.append(
              "Variable \(i.name) not in scope at \(i.sourceLocation) in function call \(functionName)"
                  + " at argument number \(i)"
          )
        }

      case .literal(let l):
        if let lit = extractLiteral(literalToken: l) {
          jsArgs.append(lit)
        } else {
          error_array.append(
              "Invalid literal found at \(l.sourceLocation) in function call \(functionName) at argument number \(i)")
        }
      case .binaryExpression(let be):
        if let func_expr = processBinaryExpression(binaryExpression: be) {
          jsArgs.append(func_expr)
        } else {
          error_array.append(
              "Invalid expression found in function call \(functionName) at argument number \(i)."
                  + "Location: \(be.sourceLocation)"
          )
        }
      default:
        break
      }
    }

    return jsArgs
  }

  private func checkFunctionArgs(functionArgs: [FunctionArgument], argTypes: [String]) -> Bool {
    if argTypes.count == 0 {
      return true
    }

    if argTypes.count != functionArgs.count {
      return false
    }

    return true
  }

  private func extractIntLitFromExpression(expression: Expression) -> Int? {
    switch expression {
    case .literal(let li):
      switch li.kind {
      case .literal(let lit):
        switch lit {
        case .decimal(let dec):
          switch dec {
          case .integer(let i):
            return i
          default:
            return nil
          }
        default:
          return nil
        }
      default:
        return nil
      }
    default:
      return nil
    }
  }

  private func getWeiVal(args: [FunctionArgument]) -> (Int, Int)? {
    for (i, a) in args.enumerated() {
      if let label = a.identifier {
        if label.name == "_wei" {
          guard let wei_val = extractIntLitFromExpression(expression: a.expression) else {
            error_array.append("Non numeric wei value found: \(a.expression.description) at \(a.sourceLocation)")
            return nil
          }

          return (i, wei_val)
        }
      }
    }

    return nil
  }

  private func processFunctionCall(functionCall: FunctionCall, lhsName: String = "") -> JSNode? {
    let fName: String = functionCall.identifier.name
    var isTransaction = false
    var resultType: String = self.NIL_TYPE

    if nil != jst.contractFunctionInfo[fName] {

    } else if JSTranslator.allFuncs.contains(fName) {

    } else if jst.getContractName() == fName {
      resultType = jst.getContractName()

    } else {
      error_array.append("Function \(functionCall.identifier.name) does not exist at \(functionCall.sourceLocation)")
      return nil
    }

    if let isFuncTransaction = jst.isFuncTransaction[fName] {
      isTransaction = isFuncTransaction
    }

    var isPayable: Bool = false
    if let funcInfo = jst.contractFunctionInfo[fName] {
      resultType = funcInfo.getType()
      isPayable = funcInfo.isPayable()
    }

    var weiVal: Int?
    var funcCallArgs = functionCall.arguments

    /*
    if !checkFuncArgs(fArgs: funcCallArgs, argTypes: argTypes) {
        error_array.append("Mismatch argument in function call \(fCall.identifier.name) at \(fCall.sourceLocation)")
        return nil
    }
    */

    if isPayable {
      guard let (idx, weiAmt) = getWeiVal(args: functionCall.arguments) else {
        error_array.append("Payable function found but wei has not been sent, add wei with argument label _wei."
                               + "Function Name: \(functionCall.identifier.name) at \(functionCall.sourceLocation)"
        )
        return nil
      }
      weiVal = weiAmt
      var firstHalf: [FunctionArgument]
      var secondHalf: [FunctionArgument]

      if idx > 0 {
        firstHalf = Array(funcCallArgs[...(idx - 1)])
        secondHalf = Array(funcCallArgs[(idx + 1)...])
      } else {
        firstHalf = []
        secondHalf = Array(funcCallArgs[(idx + 1)...])
      }

      let completeArray = firstHalf + secondHalf
      funcCallArgs = completeArray
    }

    let funcArgs = processFuncCallArgs(args: funcCallArgs, functionName: fName)

    var contractEventInfo: ContractEventInfo?
    if fName.contains("assertEventFired") {
      if let eventInfo = jst.contractEventInfo[funcArgs[0].description.replacingOccurrences(of: "\"", with: "")] {
        contractEventInfo = eventInfo
      } else {
        error_array.append("The event " + funcArgs[0].description + " does not exist at \(functionCall.sourceLocation)")
        return nil
      }
    }

    let isAssert = fName.lowercased().contains("assert")

    return .FunctionCall(
        JSFunctionCall(contractCall: jst.contractFunctionNames.contains(fName), transactionMethod: isTransaction,
                       isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs,
                       resultType: resultType, isPayable: isPayable, eventInformation: contractEventInfo,
                       weiAmount: weiVal))
  }

}
