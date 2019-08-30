import AST
import Rainbow
import Foundation
import Utils

public class REPLCodeProcessor {

  private let repl: REPL

  public init(repl: REPL) {
    self.repl = repl
  }

  private func process_equal_expr(expr: BinaryExpression) throws -> (String, String)? {

    var varName: String = ""
    var varType: String = ""
    var varConst: Bool = false
    var newVar: Bool = true

    switch expr.lhs {
    case .variableDeclaration(let vdec):
      varName = vdec.identifier.name
      varType = vdec.type.name
      varConst = vdec.isConstant
    case .identifier(let i):
      guard let rVar = repl.queryVariableMap(variable: i.name) else {
        print("Variable \(i.name) not in scope".lightRed.bold)
        return nil
      }
      varName = rVar.variableName
      varType = rVar.variableType
      varConst = rVar.varConstant
      newVar = false
    default:
      print("Invalid expression found on the LHS of an equal \(expr.rhs.description)".lightRed.bold)
      return nil
    }

    if let (res, resType) = try process_expr(expr: expr.rhs) {

      if resType != varType {
        print("Mismatch of types \(resType) != \(varType)".lightRed.bold)
        return nil
      }

      if !newVar && varConst {
        print("Cannot modify const variable \(varName)".lightRed.bold)
        return nil
      }

      let replVar = REPLVariable(variableName: varName, variableType: varType, variableValue: res, varConstant: varConst
      )
      repl.addVarToMap(replVar: replVar, name: varName)
      return (res, varType)
    } else {
      print("Invalid expression found on RHS of equal \(expr.rhs.description)".lightRed.bold)
    }
    return nil
  }

  private func process_dot_expr(expr: BinaryExpression) -> (String, String)? {
    var rC: REPLContract?
    var variableName: String = ""

    switch expr.lhs {
    case .identifier(let i):
      if let rVar = self.repl.queryVariableMap(variable: i.name) {
        if let rContract = self.repl.queryContractInfo(contractName: rVar.variableType) {
          rC = rContract
          variableName = i.name
        } else {
          print("Variable is not mapped to a contract".lightRed.bold)
          return nil
        }
      } else {
        print("Variable \(i.name) not in scope in dot expr".lightRed.bold)
        return nil
      }
    default:
      print("Only identifiers are allowed on the LHS of a dot expression".lightRed.bold)
    }

    switch expr.rhs {
    case .functionCall(let fCall):
      if let res = rC?.run(fCall: fCall, instance: variableName) {
        let resType = rC!.getResultType(fnc: fCall.identifier.name)
        return (res, resType)
      }

    case .identifier(let i):
      let name = i.name
      if rC!.getEventInfo(eventName: name) != nil {
        if let res = rC!.getEventLogs(instance: variableName, eventName: name) {
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

  private func tryDeploy(binExp: BinaryExpression) throws -> Bool {
    var typeName = ""
    var variableName = ""

    switch binExp.opToken {
    case .equal:
      switch binExp.lhs {
      case .variableDeclaration(let vdec):
        typeName = vdec.type.name
        variableName = vdec.identifier.name
      default:
        break
      }

    default:
      break
    }

    if let rC = self.repl.queryContractInfo(contractName: typeName) {
      if let addr = try rC.deploy(expr: binExp, variable_name: variableName) {

        if addr == "ERROR" {
          return true
        }

        let replVar = REPLVariable(variableName: variableName, variableType: rC.getContractName(), variableValue: addr,
                                   varConstant: true)
        repl.addVarToMap(replVar: replVar, name: variableName)
        return true
      }
    }

    return false
  }

  private func getNewAddress() -> String {
    let fileManager = FileManager.init()
    let path = Path.getFullUrl(path: "utils/repl/gen_address.js").path

    if !(fileManager.fileExists(atPath: path)) {
      print("FATAL ERROR: gen_address file does not exist, cannot gen new addr. Exiting.")
      exit(0)
    }

    let p = Process()
    #if os(macOS)
    let nodeLocation = "/usr/local/bin/node"
    #else
    let nodeLocation = "/usr/bin/node"
    #endif
    p.executableURL = URL(fileURLWithPath: nodeLocation)
    p.currentDirectoryURL = Path.getFullUrl(path: "utils/repl")
    p.arguments = ["--no-warnings", "gen_address.js"]
    p.standardInput = FileHandle.nullDevice
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try! p.run()
    p.waitUntilExit()

    let addr = try! String(contentsOf: Path.getFullUrl(path: "utils/repl/gen_addr.txt"))

    return addr

  }

  public func process_expr(expr: Expression) throws -> (String, String)? {
    switch expr {
    case .binaryExpression(let binExp):

      // returns true if this was a deployment statement
      if try tryDeploy(binExp: binExp) {
        return nil
      }

      if let (res, type) = try process_binary_expr(expr: binExp) {
        return (res, type)
      }

    case .identifier(let i):
      if let rVar = repl.queryVariableMap(variable: i.name) {
        return (rVar.variableValue, rVar.variableType)
      } else {
        print("Variable \(i.name) not in scope".lightRed.bold)
      }
    case .functionCall(let fc):
      if fc.identifier.name == "newAddress" {
        let addr = getNewAddress()

        return (addr, "Address")
      } else if fc.identifier.name == "setAddr" {
        if fc.arguments.count != 1 {
          print("Invalid number of arugments passed to setAddr".lightRed.bold)
        }

        switch fc.arguments[0].expression {
        case .identifier(let i):
          print(i)
          if let val = self.repl.queryVariableMap(variable: i.name) {
            let value = val.variableValue
            print(value)
            self.repl.transactionAddress = value
          } else {
            print("Variable \(i.description) is not in scope".lightRed.bold)
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

      } else if fc.identifier.name == "unsetAddr" {
        self.repl.transactionAddress = ""

      } else {
        print("Function \(fc.identifier.name) not in scope".lightRed.bold)
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

  private func process_arithmetic_expr(expr: BinaryExpression, op: REPLOperator) throws -> (String, String)? {

    guard let (e1, e1Type) = try process_expr(expr: expr.lhs) else {
      print("Could not process arithmetic expression".lightRed.bold)
      return nil
    }

    guard let (e2, e2Type) = try process_expr(expr: expr.rhs) else {
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

  private func process_logical_expr(expr: BinaryExpression, op: REPLOperator) throws -> (String, String)? {

    guard let (e1, e1Type) = try process_expr(expr: expr.lhs) else {
      print("Could not process logical expression".lightRed.bold)
      return nil
    }

    guard let (e2, e2Type) = try process_expr(expr: expr.rhs) else {
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

  public func process_binary_expr(expr: BinaryExpression) throws -> (String, String)? {
    switch expr.opToken {
    case .dot:
      return process_dot_expr(expr: expr)
    case .equal:
      return try process_equal_expr(expr: expr)
    case .plus:
      return try process_arithmetic_expr(expr: expr, op: .add)
    case .minus:
      return try process_arithmetic_expr(expr: expr, op: .minus)
    case .divide:
      return try process_arithmetic_expr(expr: expr, op: .divide)
    case .power:
      return try process_arithmetic_expr(expr: expr, op: .power)
    case .and:
      return try process_logical_expr(expr: expr, op: .and)
    case .or:
      return try process_logical_expr(expr: expr, op: .or)
    case .notEqual:
      print("not equal")
    case .doubleEqual:
      print("double equal")
    default:
      print("This expression is not supported: \(expr.description)".lightRed.bold)
    }

    return nil
  }
}
