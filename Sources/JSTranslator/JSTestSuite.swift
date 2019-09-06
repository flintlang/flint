import AST
import Parser
import Lexer
import Foundation
import Utils

public class JSTranslator {
  private var contractName: String
  private var filePath: String
  private var testSuiteName: String
  private let testFile: URL
  private let ast: TopLevelModule
  private var JSTestFuncs: [JSTestFunction]

  public var isFuncTransaction: [String: Bool]
  public var contractFunctionNames: [String]
  public var contractFunctionInfo: [String: ContractFuncInfo]
  public var contractEventInfo: [String: ContractEventInfo]
  public static let callerOrStateFuncs = [
    "assertCallerSat",
    "assertCallerUnsat",
    "assertCanCallInThisState",
    "assertCantCallInThisState",
    "assertEventFired",
    "assertWillThrow"]
  public static let genericAsserts = ["assertEqual"]
  public static let utilityFuncs = ["newAddress", "setAddr", "unsetAddr"]
  public static let allFuncs = JSTranslator.callerOrStateFuncs + JSTranslator.genericAsserts + JSTranslator.utilityFuncs

  private let firstHalf: String
  private let coverage: Bool

  // creates the JSTestSuite class
  public init(ast: TopLevelModule, coverage: Bool = false, testFile: URL) {
    self.contractName = ""
    self.filePath = ""
    self.testSuiteName = ""
    self.JSTestFuncs = []
    self.isFuncTransaction = [:]
    self.contractFunctionNames = []
    self.contractFunctionInfo = [:]
    self.contractEventInfo = [:]
    self.firstHalf = try! String(contentsOf: Path.getFullUrl(path: "utils/testRunner/test_framework.js"))
    self.ast = ast
    self.coverage = coverage
    self.testFile = testFile
    loadLibraryFuncs()
    loadTestContractVars()
  }

  private func loadLibraryFuncs() {
    let assertEqualInfo = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertEqual"] = assertEqualInfo

    let newAddrInfo = ContractFuncInfo(resultType: "Address", payable: false, argTypes: [])
    self.contractFunctionInfo["newAddress"] = newAddrInfo

    let setAddr = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["setAddr"] = setAddr

    let unsetAddr = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["unsetAddr"] = unsetAddr

    let assertCallerSat = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertCallerSat"] = assertCallerSat

    let assertCallerUnSat = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertCallerUnSat"] = assertCallerUnSat

    let assertCanCallInThisState = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertCanCallInThisState"] = assertCanCallInThisState

    let assertCantCallInThisState = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertCantCallInThisState"] = assertCantCallInThisState

    let assertWillThrow = ContractFuncInfo(resultType: "nil", payable: false, argTypes: [])
    self.contractFunctionInfo["assertWillThrow"] = assertWillThrow
  }

  public func getFilePathToFlintContract() -> String {
    return self.filePath
  }

  public func getContractName() -> String {
    return self.contractName
  }

  public func loadTestContractVars() {
    let declarations: [TopLevelDeclaration] = self.ast.declarations

    for declaration in declarations {
      switch declaration {
      case .contractDeclaration(let contractDec):
        processContract(contract: contractDec)
      default:
        continue
      }
    }

  }

  // this function is the entry point which takes a flint AST and translates it into a JS AST suitable for testing
  public func convertAST() {
    let declarations: [TopLevelDeclaration] = self.ast.declarations

    for declaration in declarations {
      switch declaration {
      case .contractDeclaration:
        loadContract()
      case .contractBehaviorDeclaration(let contractBehaviour):
        processContractBehaviour(contractBehaviour: contractBehaviour)
      default:
        continue
      }
    }
  }

  private func loadContract() {
    // process the contract that we actually care about
    do {
      let sourceCode = try String(contentsOf: URL(fileURLWithPath: self.filePath))
      let tokens = try Lexer(sourceFile: URL(fileURLWithPath: self.filePath),
                             isFromStdlib: false,
                             isForServer: true,
                             sourceCode: sourceCode).lex()
      let (_, environment, _) = Parser(tokens: tokens).parse()

      guard let environmentTypes = environment.types[self.contractName] else {
        print("Could not load information about contract \(self.contractName)".lightRed.bold)
        exit(0)
      }

      let contractFunctions = environmentTypes.allFunctions

      let contractEvents = environmentTypes.allEvents

      // process contract event information
      for (eventName, allEventsWithName) in contractEvents {
        // this will always exist if the parse tree has been constructed
        let e = allEventsWithName[0]
        var eventArgs: [(String, String)] = []
        var count = 0
        let parameterTypes = e.eventTypes
        for identifier in e.parameterIdentifiers {
          let paramInfo = (identifier.name, parameterTypes[count].name)
          eventArgs.append(paramInfo)
          count += 1
        }
        let contractInfo = ContractEventInfo(name: eventName, event_args: eventArgs)
        contractEventInfo[eventName] = contractInfo
      }

      for (functionName, allFuncsWithName) in contractFunctions where allFuncsWithName.count > 0 {
        isFuncTransaction[functionName] =
        allFuncsWithName[0].isMutating || allFuncsWithName[0].declaration.isPayable || self.coverage

        for stm in allFuncsWithName[0].declaration.body {
          switch stm {
          case .emitStatement:
            isFuncTransaction[functionName] = true
          default:
            continue
          }
        }

        var resultTypeVal = "nil"
        if let resultType = allFuncsWithName[0].declaration.signature.resultType {
          resultTypeVal = resultType.name
        }

        var argTypes: [String] = []

        for a in allFuncsWithName[0].parameterTypes {
          switch a {
          case .basicType(let rt):
            argTypes.append(rt.rawValue)
          default:
            continue
          }
        }

        contractFunctionInfo[functionName] = ContractFuncInfo(resultType: resultTypeVal,
                                                              payable: allFuncsWithName[0].declaration.isPayable,
                                                              argTypes: argTypes)
        contractFunctionNames.append(functionName)
      }

    } catch {
      print("Fatal error: Loading of contract that is to be tested has failed".lightRed.bold)
      exit(EXIT_FAILURE)
    }
  }

  private func processContractBehaviour(contractBehaviour: ContractBehaviorDeclaration) {

    let members: [ContractBehaviorMember] = contractBehaviour.members

    for member in members {
      switch member {
      case .functionDeclaration(let functionDeclaration):
        //
        let functionTranslator = FunctionTranslator(jst: self)
        let (jsFunction, errors) = functionTranslator.translate(functionDeclaration: functionDeclaration)

        if errors.count > 0 {
          var error = ""
          for e in errors {
            error += e.lightRed.bold + "\n\n"
          }
          print(error)
          exit(0)
        }

        if let function = jsFunction {
          JSTestFuncs.append(function)
        }

      default:
        continue
      }
    }
  }

  private func processContract(contract: ContractDeclaration) {
    let members: [ContractMember] = contract.members

    for member in members {
      switch member {
      case .variableDeclaration(let variableDeclaration):
        processContractVars(variableDeclaration: variableDeclaration)
      default:
        continue
      }
    }
  }

  private func getStringFromExpression(expression: Expression) -> String {
    var fileName: String = ""
    switch expression {
    case .literal(let t):
      switch t.kind {
      case .literal(let lit):
        switch lit {
        case .string(let str):
          fileName = str
        default:
          break
        }
      default:
        break
      }
    default:
      break
    }

    return fileName
  }

  private func processContractVars(variableDeclaration: VariableDeclaration) {
    let nameOfVar: String = variableDeclaration.identifier.name

    if nameOfVar == "filePath" {
      let filePathVar: String = getStringFromExpression(expression: variableDeclaration.assignedExpression!)
      // Allow for both absolute and relative (to the testFile) path
      let fileToTest = URL(fileURLWithPath: filePathVar, relativeTo: testFile.deletingLastPathComponent())
      self.filePath = fileToTest.path
    } else if nameOfVar == "contractName" {
      self.contractName = getStringFromExpression(expression: variableDeclaration.assignedExpression!)

    } else if nameOfVar == "TestSuiteName" {
      self.testSuiteName = getStringFromExpression(expression: variableDeclaration.assignedExpression!)
    }
  }

  private func genRunTests() -> String {
    var function = "async function run_tests(pathToContract, nameOfContract) {\n"
    function += "    let source = fs.readFileSync(pathToContract, 'utf8'); \n"
    function += "    let compiledContract = solc.compile(source, 1); \n"
    function += "    fs.writeFileSync(\"../coverage/contract.json\", JSON.stringify(compiledContract)); \n"
    function += "    fs.writeFileSync(\"../coverage/address.txt\", \"\"); \n"
    function += "    let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface; \n"
    function += "    let bytecode = \"0x\" + compiledContract.contracts[':' + nameOfContract].bytecode; \n"
    function += "    console.log(chalk.green(\"Running test suite: \(self.testSuiteName)\")); \n"

    var counter: Int = 0
    for testFunction in JSTestFuncs {
      function += "    let depContract_\(counter) = await deploy_contract(abi, bytecode); \n"
      function += "    fs.appendFileSync(\"../coverage/address.txt\", \"\(testFunction.getFuncName()): \""
      + " + depContract_\(counter).address + \"\\n\"); \n"
      function += "    await " + testFunction.getFuncName() + "(depContract_\(counter)) \n"
      counter += 1
    }

    function += "}\n\n"
    return function
  }

  // this is the function that generates the string representation of the JS file -> ready for execution
  public func genFile() -> String {
    var file = firstHalf
    for testFunc in JSTestFuncs {
      file += testFunc.description + "\n"
    }

    file += "\n"

    file += genRunTests()

    file +=
        """
        function  main(pathToContract, nameOfContract) {
            run_tests(pathToContract, nameOfContract)
        } \n\n
        """

    file += "main('main.sol', '\(self.contractName)');"

    return file
  }
}
