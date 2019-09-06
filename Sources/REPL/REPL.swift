import Compiler
import Parser
import AST
import Lexer
import Diagnostic
import Foundation
import JSTranslator
import SwiftyJSON
import Rainbow
import Utils

public class REPL {
  var contractInfoMap: [String: REPLContract] = [:]
  var variableMap: [String: REPLVariable] = [:]
  let contractFilePath: String
  public var transactionAddress: String = ""

  public init(contractFilePath: String, contractAddress: String = "") {
    self.contractFilePath = contractFilePath
  }

  func getContractData() throws -> String {
    let fileManager = FileManager()
    let path = Path.getFullUrl(path: "utils/repl/compile_contract.js").path
    if !fileManager.fileExists(atPath: path) {
      print("FATAL ERROR: compile_contract file does not exist, cannot compile contract for repl. Exiting.")
      exit(0)
    }

    Process.run(executableURL: Configuration.nodeLocation,
                arguments: ["--no-warnings", "compile_contract.js"],
                currentDirectoryURL: Path.getFullUrl(path: "utils/repl"))

    let contractJsonFile = Path.getFullUrl(path: "utils/repl/contract.json")
    return try String(contentsOf: contractJsonFile)
  }

  public func queryContractInfo(contractName: String) -> REPLContract? {
    return contractInfoMap[contractName]
  }

  public func queryVariableMap(variable: String) -> REPLVariable? {
    return variableMap[variable]
  }

  private func processAbiArgs(args: [[String: String]], payable: Bool = false) -> String {
    var finalArgs = "("

    if payable {
      finalArgs += "_wei: Wei".lightGreen + ", "
    }

    let finalCount = args.count
    for (i, a) in args.enumerated() {
      let argName = a["name"]!
      let argType = a["type"]!

      var flintType = ""
      if argType == "uint256" {
        flintType = "Int"
      } else if argType == "bytes32" {
        flintType = "String"
      } else if argType == "address" {
        flintType = "Address"
      } else {
        flintType = argType
      }

      var flintArg = argName
      flintArg.remove(at: flintArg.startIndex)
      finalArgs += "\(flintArg) : \(flintType)"
      if i != finalCount - 1 {
        finalArgs += ", "
      }

    }

    finalArgs += ")"

    return finalArgs
  }

  private func prettyPrintAbi(abi: String) throws {

    let abiArray = try JSONSerialization.jsonObject(with: abi.data(using: .utf8)!, options: []) as? [[String: Any]]

    var abiPrettyFunctions: [String] = []

    for element in abiArray! {
      guard let type = element["type"]! as? String else {
        fatalError()
      }
      if type == "function" {
        guard let payable = element["payable"] as? Bool else {
          fatalError()
        }
        guard var functionName = element["name"] as? String else {
          fatalError()
        }
        if functionName == "replConstructor" {
          functionName = "init".lightBlue
        }
        guard let inputs = element["inputs"] as? [[String: String]] else {
          fatalError()
        }
        guard let isConstant = element["constant"] as? Bool else {
          fatalError()
        }
        //let outputs = elem["outputs"] as! [[String : String]]
        let functionSignature = "\(functionName)\(processAbiArgs(args: inputs, payable: payable))"
        if isConstant {
          abiPrettyFunctions.append(functionSignature.lightWhite + " (Constant)".lightCyan.bold)
        } else {
          if payable {
            abiPrettyFunctions.append(functionSignature.lightWhite + " (Mutating, Payable)".lightYellow.bold)
          } else {
            abiPrettyFunctions.append(functionSignature.lightWhite + " (Mutating)".lightYellow.bold)
          }
        }
      }
    }

    var finalFunctionsString = ""
    finalFunctionsString += "Contract Functions: \n".lightGreen
    for funcs in abiPrettyFunctions {
      finalFunctionsString += funcs + "\n"
    }

    print(finalFunctionsString)
  }

  private func deployContracts() {
    let inputFiles = [URL(fileURLWithPath: self.contractFilePath)]
    let outputDirectory = Path.getFullUrl(path: "utils/repl")
    let config = CompilerReplConfiguration(sourceFiles: inputFiles,
                                           stdlibFiles: StandardLibrary.from(target: .evm).files,
                                           outputDirectory: outputDirectory,
                                           diagnostics: DiagnosticPool(shouldVerify: false, quiet: false,
                                                                       sourceContext: SourceContext(
                                                                           sourceFiles: inputFiles)))

    do {
      let (ast, environment) = try Compiler.getAST(config: config)

      try Compiler.genSolFile(config: config, ast: ast, environment: environment)
      print("Generated solidity file")

      let contractData = try getContractData()
      print("Got contract data")

      guard let dataFromString = contractData.data(using: .utf8, allowLossyConversion: false) else {
        print("ERROR : Unable to extract contract information")
        exit(0)
      }

      let json = try JSON(data: dataFromString)

      for declaration in ast.declarations {
        switch declaration {
        case .contractDeclaration(let contractDeclaration):
          let contractName = contractDeclaration.identifier.name

          guard let bytecode = json["contracts"][":" + contractName]["bytecode"].string else {
            print("Could not extract the bytecode for \(contractName). Exiting Repl".lightRed.bold)
            exit(0)
          }

          guard let abi = json["contracts"][":_Interface" + contractName]["interface"].string else {
            print("Could not extract the abi for \(contractName)".lightRed.bold)
            exit(0)
          }

          print("\(contractName): \n".bold.underline.lightWhite)

          let replContract = REPLContract(contractFilePath: self.contractFilePath,
                                          contractName: contractName,
                                          abi: abi,
                                          bytecode: "0x" + bytecode, repl: self)
          try prettyPrintAbi(abi: abi)
          contractInfoMap[contractName] = replContract

        default:
          continue
        }
      }

      print("Contracts deployed")
    } catch let err {
      print(err)
      print("Contract file \(self.contractFilePath) was not deployed")
    }
  }

  public func addVarToMap(replVar: REPLVariable, name: String) {
    variableMap[name] = replVar
  }

  public func run() throws {
    deployContracts()
    let replCodeProcessor: REPLCodeProcessor = REPLCodeProcessor(repl: self)
    do {
      print("flint>".lightMagenta, terminator: "")
      while var input = readLine() {

        guard input != ".exit" else {
          break
        }

        if input == "" {
          continue
        }

        input = "{" + input + "}"

        let lex = Lexer(sourceCode: input)
        let tokens = lex.lex()
        let parser = Parser(tokens: tokens)
        let (statements, diagnostics) = parser.parseREPL()

        if statements.count == 0 {
          print(try DiagnosticsFormatter(diagnostics: diagnostics, sourceContext: nil).rendered())
        }

        for statement in statements {
          switch statement {
          case .expression(let expression):
            if let (res, _) = try replCodeProcessor.processExpression(expression: expression) {
              print(res.trimmingCharacters(in: .whitespacesAndNewlines).lightWhite.bold)
            }
          default:
            print("Syntax is not currently supported".lightRed.bold)
          }
        }

        print("flint>".lightMagenta, terminator: "")
      }

    } catch let err {
      print(err)
    }
  }
}
