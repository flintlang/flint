import JSTranslator
import AST
import Parser
import Lexer
import Diagnostic
import Foundation
import Rainbow
import SwiftyJSON
import Utils

public class REPLContract {
  private var isFuncTransaction: [String: Bool]
  private var contractFunctionNames: [String]
  private var contractFunctionInfo: [String: ContractFuncInfo]
  private var contractEventInfo: [String: ContractEventInfo]
  private var instanceToAddress: [String: String]
  private let contractFilePath: String
  private let contractName: String
  private let abi: String
  private let bytecode: String
  private let repl: REPL

  public init(contractFilePath: String, contractName: String, abi: String, bytecode: String, repl: REPL) {
    self.contractFilePath = contractFilePath
    self.contractName = contractName
    self.contractFunctionInfo = [:]
    self.contractEventInfo = [:]
    self.contractFunctionNames = []
    self.isFuncTransaction = [:]
    self.instanceToAddress = [:]
    self.abi = abi
    self.bytecode = bytecode
    self.repl = repl
    loadContract()
  }

  public func getEventInfo(eventName: String) -> ContractEventInfo? {
    if let ev = contractEventInfo[eventName] {
      return ev
    }

    return nil
  }

  public func getEventLogs(instance: String, eventName: String) -> String? {
    let abi = self.abi
    let addr = self.instanceToAddress[instance]!
    let eventName = eventName

    guard let eventInfo = contractEventInfo[eventName] else {
      print("Event \(eventName) was not found in contract \(contractName)".lightRed.bold)
      return nil
    }

    let event_args = eventInfo.getArgs()

    var eventArgNames: [String] = []
    var eventArgToTypes: [String: String] = [:]

    for earg in event_args {
      eventArgNames.append(earg.0)
      eventArgToTypes[earg.0] = earg.1
    }

    let json_event_arg_names: String = String(
        data: try! JSONSerialization.data(withJSONObject: eventArgNames, options: []), encoding: .utf8)!

    let json_event_arg_to_types: String = String(
        data: try! JSONSerialization.data(withJSONObject: eventArgToTypes, options: []), encoding: .utf8)!

    Process.run(executableURL: Configuration.nodeLocation,
                arguments: ["event.js", abi, addr, eventName, json_event_arg_names, json_event_arg_to_types],
                currentDirectoryURL: Path.getFullUrl(path: "utils/repl"))

    if let res = try? String(contentsOf: Path.getFullUrl(path: "utils/repl/event_result.txt")) {
      return res
    }

    return nil

  }

  public func getContractName() -> String {
    return contractName
  }

  public func getResultType(fnc: String) -> String {
    return contractFunctionInfo[fnc]!.getType()
  }

  private func extractWeiArgument(args: [FunctionArgument]) -> (Int, [FunctionArgument])? {
    if args.count > 0 {
      let weiArg = args[0]

      guard let parameterName = weiArg.identifier else {
        print(("Function is payable but no wei was sent, please send wei using the _wei parameter,"
            + "_wei should be the first parameter").lightRed.bold)
        return nil
      }

      if parameterName.name != "_wei" {
        print(("Function is payable but no wei was sent, please send wei using the _wei parameter,"
            + " _wei should be the first parameter").lightRed.bold)
        return nil
      }

      switch weiArg.expression {
      case .literal(let li):
        switch li.kind {
        case .literal(let lit):
          switch lit {
          case .decimal(let dec):
            switch dec {
            case .integer(let i):
              return (i, Array(args[1...]))
            default:
              print("Invalid type found for Wei value".lightRed.bold)
            }
          default:
            print("Invalid type found for Wei value".lightRed.bold)
          }
        default:
          print("Invalid type found for Wei value".lightRed.bold)
        }
      default:
        print("Invalid type found for Wei value".lightRed.bold)
      }
    }

    return nil
  }

  public func run(functionCall: FunctionCall, instance: String, expression: Expression? = nil) -> String? {
    guard let address = instanceToAddress[instance] else {
      print("\(instance) is not in scope.".lightRed.bold)
      return nil
    }

    guard let functionInfo = contractFunctionInfo[functionCall.identifier.name] else {
      print("Function : \(functionCall.identifier.name) was not found in contract \(self.contractName)".lightRed.bold)
      return nil
    }

    var functionArgs: [FunctionArgument] = functionCall.arguments
    var weiValue: Int?
    if contractFunctionInfo[functionCall.identifier.name]!.isPayable() {
      guard let (weiVal, remainingArgs) = extractWeiArgument(args: functionArgs) else {
        return nil
      }
      functionArgs = remainingArgs
      weiValue = weiVal
    }

    guard let fArgs = processFuncCallArgs(args: functionArgs) else {
      print("Failed to run function \(functionCall.identifier.name) as arguments were malformed".lightRed.bold)
      return nil
    }

    guard let argsData = try? JSONSerialization.data(withJSONObject: fArgs, options: []) else {
      print("Failed to process arguments for \(functionCall.identifier.name)".lightRed.bold)
      return nil
    }

    guard let args = String(data: argsData, encoding: .utf8) else {
      print("Failed to process arguments for \(functionCall.identifier.name)".lightRed.bold)
      return nil
    }

    guard let isTransaction = isFuncTransaction[functionCall.identifier.name] else {
      print("Function : \(functionCall.identifier.name) was not found in contract \(self.contractName)".lightRed.bold)
      return nil
    }

    let resType = functionInfo.getType()

    let transactionAddress = self.repl.transactionAddress

    let fileManager = FileManager()
    let path = Path.getFullUrl(path: "utils/repl/run_function.js").path

    if !(fileManager.fileExists(atPath: path)) {
      print("FATAL ERROR: run_function file does not exist, cannot deploy contract for repl. Exiting.".lightRed.bold)
      exit(0)
    }

    var node_args = [
      "run_function.js",
      self.abi,
      address,
      functionCall.identifier.name,
      isTransaction.description,
      resType,
      args,
      transactionAddress,
      false.description]

    if let weiVal = weiValue {
      node_args = [
        "run_function.js",
        self.abi,
        address.trimmingCharacters(in: .whitespacesAndNewlines),
        functionCall.identifier.name,
        isTransaction.description,
        resType,
        args,
        transactionAddress,
        true.description,
        weiVal.description
      ]
    }

    print("Running function call...")
    Process.run(executableURL: Configuration.nodeLocation,
                arguments: node_args,
                currentDirectoryURL: Path.getFullUrl(path: "utils/repl"))

    let resultFile = Path.getFullUrl(path: "utils/repl/result.txt")
    guard let result = try? String(contentsOf: resultFile) else {
      print("Could not extract result of function \(functionCall.identifier.name)".lightRed.bold)
      return nil
    }

    return result
  }

  private func processFuncCallArgs(args: [FunctionArgument]) -> [String]? {
    var resultArgs: [String] = []

    for arg in args {
      guard arg.identifier != nil else {
        print("Missing labels to argument for function call, missing for expr: \(arg.expression)".lightRed.bold)
        return nil
      }
      switch arg.expression {
      case .binaryExpression(let binaryExpression):
        switch binaryExpression.opToken {
        case .dot:
          switch binaryExpression.lhs {
          case .identifier(let identifier):
            if let replVariable = repl.queryVariableMap(variable: identifier.name) {
              let contractType = replVariable.variableType
              if let replContract = repl.queryContractInfo(contractName: contractType) {
                switch binaryExpression.rhs {
                case .functionCall(let functionCall):
                  if let result = replContract.run(functionCall: functionCall, instance: replVariable.variableName) {
                    resultArgs.append(result)
                  } else {
                    print("Was not able to run \(functionCall.description)".lightRed.bold)
                    return nil
                  }
                default:
                  print("Only function calls on rhs of dot expressions are currently supported".lightRed.bold)
                  return nil
                }
              }

            } else {
              print("Variable \(identifier.name) is not in scope.".lightRed.bold)
              return nil
            }
          default:
            print("Identfier not found on lhs of dot expression".lightRed.bold)
            return nil
          }
        default:
          print("Only supported expression is dot expressions. \(binaryExpression.description) is not yet supported"
            .lightRed.bold)
          return nil
        }

      case .identifier(let identifier):
        if let val = repl.queryVariableMap(variable: identifier.name) {
          resultArgs.append(val.variableValue)
        } else {
          print("Variable \(identifier.name) is not in scope.".lightRed.bold)
          return nil
        }
      case .literal(let li):
        switch li.kind {
        case .literal(let lit):
          switch lit {
          case .address(let s):
            resultArgs.append(s)
          case .boolean(let bool):
            resultArgs.append(bool.rawValue)
          case .string(let s):
            resultArgs.append(s)
          case .decimal(let decLit):
            switch decLit {
            case .integer(let i):
              resultArgs.append(i.description)
            case .real(let i1, let i2):
              resultArgs.append(i1.description + "." + i2.description)
            }
          }
        default:
          print("ERROR: Found non literal in literal token. Exiting REPL".lightRed.bold)
          return nil
        }

      default:
        print("This argument type (name: \(arg.identifier!.name)  value : "
                  + "\(arg.expression.description)) is not supported".lightRed.bold)

        return nil
      }
    }

    return resultArgs
  }

  public func deploy(expression: BinaryExpression, variableName: String) throws -> String? {
    let rhs = expression.rhs
    var args: [String]
    switch rhs {
    case .functionCall(let functionCall):

      if functionCall.identifier.name != self.contractName {
        print("Mismatch of contract types \(functionCall.identifier.name) != \(self.contractName)".lightRed.bold)
        return "ERROR"
      }

      let functionCallArgs = functionCall.arguments
      if let functionArgs = processFuncCallArgs(args: functionCallArgs) {
        args = functionArgs
      } else {
        print(("Invalid argument found in constructor function. "
            + "Failing deployment of  \(variableName) : \(self.contractName).").lightRed.bold)
        return nil
      }
    default:
      print(("Invalid expression on rhs of contract insantiation. "
          + "Failing deployment of \(variableName) : \(self.contractName).").lightRed.bold)
      return nil
    }

    let jsonArgs = JSON(args)

    guard let rawString = jsonArgs.rawString() else {
      print("Could not extract JSON constructor arguments".lightRed.bold)
      return nil
    }

    let fileManager = FileManager()
    let path = Path.getFullUrl(path: "utils/repl/deploy_contract.js").path

    if !(fileManager.fileExists(atPath: path)) {
      print("FATAL ERROR: deploy_contract file does not exist, cannot deploy contract for repl. Exiting.".lightRed.bold)
      exit(0)
    }

    print("Deploying \(variableName) : \(self.contractName)".lightGreen)
    let processResult = Process.run(executableURL: Configuration.nodeLocation,
                                    arguments: ["deploy_contract.js", self.abi, self.bytecode, rawString],
                                    currentDirectoryURL: Path.getFullUrl(path: "utils/repl"))
    if let addr = processResult.standardOutputResult {
      instanceToAddress[variableName] = addr
      print(
          "Contract deployed at address: ".lightGreen + addr.trimmingCharacters(in: .whitespacesAndNewlines).lightWhite)
      return addr
    } else {
      print("ERROR : Could not deploy contract \(self.contractName)".lightRed.bold)
      return nil
    }
  }

  private func loadContract() {
    do {
      let sourceCode = try String(contentsOf: URL(fileURLWithPath: self.contractFilePath))
      let tokens = try Lexer(sourceFile: URL(fileURLWithPath: self.contractFilePath), isFromStdlib: false,
                             isForServer: true, sourceCode: sourceCode).lex()
      let (_, environment, _) = Parser(tokens: tokens).parse()

      let contractFunctions = environment.types[self.contractName]!.allFunctions
      let contractEvents = environment.types[self.contractName]!.allEvents

      // process contract event information
      for (eventName, allEventsWithName) in contractEvents {
        // this will always exist if the parse tree has been constructed
        let eventInformation = allEventsWithName[0]
        var eventArgs: [(String, String)] = []
        var count = 0
        let paramTypes = eventInformation.eventTypes
        for identifier in eventInformation.parameterIdentifiers {
          let paramInfo = (identifier.name, paramTypes[count].name)
          eventArgs.append(paramInfo)
          count += 1
        }
        let contractInfo = ContractEventInfo(name: eventName, event_args: eventArgs)
        contractEventInfo[eventName] = contractInfo
      }

      for (functionName, allFunctionsWithName) in contractFunctions where allFunctionsWithName.count > 0 {
        isFuncTransaction[functionName]
          = allFunctionsWithName[0].isMutating || allFunctionsWithName[0].declaration.isPayable
        for statement in allFunctionsWithName[0].declaration.body {
          switch statement {
          case .emitStatement:
            isFuncTransaction[functionName] = true
          default:
            continue
          }
        }

        var resultTypeVal = "nil"
        if let resultType = allFunctionsWithName[0].declaration.signature.resultType {
          resultTypeVal = resultType.name
        }

        contractFunctionInfo[functionName] = ContractFuncInfo(resultType: resultTypeVal,
                                                       payable: allFunctionsWithName[0].declaration.isPayable)
        contractFunctionNames.append(functionName)
      }
    } catch {
      print("Fatal error")
      exit(EXIT_FAILURE)
    }
  }

}
