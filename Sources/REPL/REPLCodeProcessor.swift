import AST
import Rainbow
import Foundation
import Utils

public class REPLCodeProcessor {

  private let repl: REPL

  public init(repl: REPL) {
    self.repl = repl
  }

  private func processEqualExpression(expression: BinaryExpression) throws -> (String, String)? {

    var varName: String = ""
    var varType: String = ""
    var varConst: Bool = false
    var newVar: Bool = true

    switch expression.lhs {
    case .variableDeclaration(let variableDeclaration):
      varName = variableDeclaration.identifier.name
      varType = variableDeclaration.type.name
      varConst = variableDeclaration.isConstant
    case .identifier(let identifier):
      guard let replVar = repl.queryVariableMap(variable: identifier.name) else {
        print("Variable \(identifier.name) not in scope".lightRed.bold)
        return nil
      }
      varName = replVar.variableName
      varType = replVar.variableType
      varConst = replVar.varConstant
      newVar = false
    default:
      print("Invalid expression found on the LHS of an equal \(expression.rhs.description)".lightRed.bold)
      return nil
    }

    if let (res, resType) = try processExpression(expression: expression.rhs) {

      if resType != varType {
        print("Mismatch of types \(resType) != \(varType)".lightRed.bold)
        return nil
      }

      if !newVar && varConst {
        print("Cannot modify const variable \(varName)".lightRed.bold)
        return nil
      }

      let replVar = REPLVariable(variableName: varName,
                                 variableType: varType,
                                 variableValue: res,
                                 varConstant: varConst)
      repl.addVarToMap(replVar: replVar, name: varName)
      return (res, varType)
    } else {
      print("Invalid expression found on RHS of equal \(expression.rhs.description)".lightRed.bold)
    }
    return nil
  }

  private func processDotExpression(expression: BinaryExpression) -> (String, String)? {
    var optionalReplContract: REPLContract?
    var variableName: String = ""

    switch expression.lhs {
    case .identifier(let identifier):
      if let replVariable = self.repl.queryVariableMap(variable: identifier.name) {
        if let replContract = self.repl.queryContractInfo(contractName: replVariable.variableType) {
          optionalReplContract = replContract
          variableName = identifier.name
        } else {
          print("Variable is not mapped to a contract".lightRed.bold)
          return nil
        }
      } else {
        print("Variable \(identifier.name) not in scope in dot expr".lightRed.bold)
        return nil
      }
    default:
      print("Only identifiers are allowed on the LHS of a dot expression".lightRed.bold)
    }

    switch expression.rhs {
    case .functionCall(let functionCall):
      if let res = optionalReplContract?.run(functionCall: functionCall, instance: variableName) {
        let resType = optionalReplContract!.getResultType(fnc: functionCall.identifier.name)
        return (res, resType)
      }

    case .identifier(let identifier):
      let name = identifier.name
      if optionalReplContract!.getEventInfo(eventName: name) != nil {
        if let res = optionalReplContract!.getEventLogs(instance: variableName, eventName: name) {
          return (res, "nil")
        } else {
          print("Could not process logs for event \(name)".lightRed.bold)
          return nil
        }
      } else {
        print("\(name) is not a member of contract \(variableName)".lightRed.bold)
      }
    default:
      print("Not supported yet")
    }

    return nil
  }

  private func tryDeploy(binaryExpression: BinaryExpression) throws -> Bool {
    var typeName = ""
    var variableName = ""

    switch binaryExpression.opToken {
    case .equal:
      switch binaryExpression.lhs {
      case .variableDeclaration(let variableDeclaration):
        typeName = variableDeclaration.type.name
        variableName = variableDeclaration.identifier.name
      default:
        break
      }

    default:
      break
    }

    if let replContract = self.repl.queryContractInfo(contractName: typeName) {
      if let addr = try replContract.deploy(expression: binaryExpression, variableName: variableName) {

        if addr == "ERROR" {
          return true
        }

        let replVar = REPLVariable(variableName: variableName,
                                   variableType: replContract.getContractName(),
                                   variableValue: addr,
                                   varConstant: true)
        repl.addVarToMap(replVar: replVar, name: variableName)
        return true
      }
    }

    return false
  }

  private func getNewAddress() -> String {
    let fileManager = FileManager()
    let path = Path.getFullUrl(path: "utils/repl/gen_address.js").path

    if !(fileManager.fileExists(atPath: path)) {
      print("FATAL ERROR: gen_address file does not exist, cannot gen new addr. Exiting.")
      exit(0)
    }

    Process.run(executableURL: Configuration.nodeLocation,
                arguments: ["--no-warnings", "gen_address.js"],
                currentDirectoryURL: Path.getFullUrl(path: "utils/repl"))
    let addr = try! String(contentsOf: Path.getFullUrl(path: "utils/repl/gen_addr.txt"))
    return addr

  }

  public func processExpression(expression: Expression) throws -> (String, String)? {
    switch expression {
    case .binaryExpression(let binaryExpression):

      // returns true if this was a deployment statement
      if try tryDeploy(binaryExpression: binaryExpression) {
        return nil
      }

      if let (res, type) = try processBinaryExpression(expression: binaryExpression) {
        return (res, type)
      }

    case .identifier(let identifier):
      if let replVar = repl.queryVariableMap(variable: identifier.name) {
        return (replVar.variableValue, replVar.variableType)
      } else {
        print("Variable \(identifier.name) not in scope".lightRed.bold)
      }
    case .functionCall(let functionCall):
      if functionCall.identifier.name == "newAddress" {
        let addr = getNewAddress()

        return (addr, "Address")
      } else if functionCall.identifier.name == "setAddr" {
        if functionCall.arguments.count != 1 {
          print("Invalid number of arugments passed to setAddr".lightRed.bold)
        }

        switch functionCall.arguments[0].expression {
        case .identifier(let identifier):
          print(identifier)
          if let val = self.repl.queryVariableMap(variable: identifier.name) {
            let value = val.variableValue
            print(value)
            self.repl.transactionAddress = value
          } else {
            print("Variable \(identifier.description) is not in scope".lightRed.bold)
            return nil
          }
        case .literal(let lit):
          switch lit.kind {
          case .literal(let literal):
            switch literal {
            case .address(let s):
              self.repl.transactionAddress = s
            default:
              print("Non-sddress literal passed into SetAddr".lightRed.bold)
            }
          default:
            print("Invalid expression passed to setAddr".lightRed.bold)
          }
        default:
          print("Invalid expression passed to setAddr".lightRed.bold)
        }

      } else if functionCall.identifier.name == "unsetAddr" {
        self.repl.transactionAddress = ""

      } else {
        print("Function \(functionCall.identifier.name) not in scope".lightRed.bold)
      }
    case .literal(let li):
      switch li.kind {
      case .literal(let lit):
        switch lit {
        case .string(let s):
          return (s, "String")
        case .decimal(let dec):
          switch dec {
          case .integer(let i):
            return (i.description, "Int")
          default:
            print("Floating point numbers are not supported".lightRed.bold)
          }
        case .address(let a):
          return (a, "Address")
        case .boolean(let b):
          if b.rawValue == "true" {
            return ("1", "Bool")
          } else {
            return ("0", "Bool")
          }
        }
      default:
        print("ERROR: Invalid token found \(li.description)".lightRed.bold)
      }
    default:
      print("Syntax is not supported".lightRed.bold)
    }

    return nil
  }

  private func processArithmeticExpression(expression: BinaryExpression, op: REPLOperator) throws -> (String, String)? {

    guard let (e1, e1Type) = try processExpression(expression: expression.lhs) else {
      print("Could not process arithmetic expression".lightRed.bold)
      return nil
    }

    guard let (e2, e2Type) = try processExpression(expression: expression.rhs) else {
      print("Could not process arithmetic expression".lightRed.bold)
      return nil
    }

    if e2Type != "Int" || e1Type != "Int" {
      print("Invalid type passed to arithmetic addition operation".lightRed.bold)
      return nil
    }

    guard let e1Int = Int(e1) else {
      print("NaN found in arithmetic expression operands".lightRed.bold)
      return nil
    }

    guard let e2Int = Int(e2) else {
      print("NaN found in arithmetic expression operands".lightRed.bold)
      return nil
    }

    switch op {
    case .add:
      return ((e1Int + e2Int).description, "Int")
    case .divide:
      return ((e1Int / e2Int).description, "Int")
    case .minus:
      return ((e1Int - e2Int).description, "Int")
    case .power:
      return ((e1Int ^ e2Int).description, "Int")
    default:
      print("Not an arithmetic operator".lightRed.bold)
      return nil
    }

  }

  private func processLogicalExpression(expression: BinaryExpression, op: REPLOperator) throws -> (String, String)? {

    guard let (e1, e1Type) = try processExpression(expression: expression.lhs) else {
      print("Could not process logical expression".lightRed.bold)
      return nil
    }

    guard let (e2, e2Type) = try processExpression(expression: expression.rhs) else {
      print("Could not process logical expression".lightRed.bold)
      return nil
    }

    if e2Type != "Bool" || e1Type != "Bool" {
      print("Invalid type passed to logical operation".lightRed.bold)
      return nil
    }

    let e1ActualBool = e1 == "1"
    let e2ActualBool = e2 == "1"

    switch op {
    case .and:
      var res = "0"
      if (e1ActualBool && e2ActualBool).description == "true" {
        res = "1"
      }
      return (res, "Bool")
    case .or:
      var res = "0"
      if (e1ActualBool || e2ActualBool).description == "true" {
        res = "1"
      }
      return (res, "Bool")
    default:
      print("Unsupported logical operator".lightRed.bold)
      return nil
    }

  }

  public func processBinaryExpression(expression: BinaryExpression) throws -> (String, String)? {
    switch expression.opToken {
    case .dot:
      return processDotExpression(expression: expression)
    case .equal:
      return try processEqualExpression(expression: expression)
    case .plus:
      return try processArithmeticExpression(expression: expression, op: .add)
    case .minus:
      return try processArithmeticExpression(expression: expression, op: .minus)
    case .divide:
      return try processArithmeticExpression(expression: expression, op: .divide)
    case .power:
      return try processArithmeticExpression(expression: expression, op: .power)
    case .and:
      return try processLogicalExpression(expression: expression, op: .and)
    case .or:
      return try processLogicalExpression(expression: expression, op: .or)
    case .notEqual:
      print("not equal")
    case .doubleEqual:
      print("double equal")
    default:
      print("This expression is not supported: \(expression.description)".lightRed.bold)
    }

    return nil
  }
}
