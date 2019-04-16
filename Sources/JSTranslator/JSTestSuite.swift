import AST
import Parser
import Lexer
import Foundation

public class JSTestSuite {
    // for now lets write this to support a single test contract
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private var JSTestFuncs: [JSTestFunction]
    
    private var isFuncTransaction : [String:Bool]
    private var contractFunctionNames : [String]

    // creates the JSTestSuite class
    public init() {
        contractName = ""
        filePath = ""
        testSuiteName = ""
        JSTestFuncs = []
        isFuncTransaction = [:]
        contractFunctionNames = []
    }
    
    // this function is the entry point which takes a flint AST and translates it into a JS AST suitable for testing
    public func convertAST(ast: TopLevelModule) {
        let declarations : [TopLevelDeclaration] = ast.declarations
        
        for d in declarations {
            switch d {
            case .contractDeclaration(let contractDec):
                processContract(contract: contractDec)
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
            let tokens = try Lexer(sourceFile: URL(fileURLWithPath: self.filePath), isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
            let (_, environment, parserDiagnostics) = try Parser(tokens: tokens).parse()
            
            if (environment.syntaxErrors)
            {
                // print syntax errors before exiting and also use throw
                print("failed to compile contract")
                exit(1)
            }
            
            let contractFunctions = environment.types[self.contractName]!.allFunctions
            
            for (fName, allFuncsWithName) in contractFunctions {
                if (allFuncsWithName.count > 0)
                {
                    isFuncTransaction[fName] = allFuncsWithName[0].isMutating
                    contractFunctionNames.append(fName)
                }
            }
            
        } catch {
            print("failed to compile contract")
            exit(1)
        }
    }
    
    private func processContractBehaviour(contractBehaviour: ContractBehaviorDeclaration)
    {
        
        let members : [ContractBehaviorMember] = contractBehaviour.members
        
        // process each of the function declarations
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                if let fnc = processContractFunction(fdec: fdec) {
                    JSTestFuncs.append(fnc)
                }
            default:
                continue
            }
        }
    }
    
    private func processContractFunction(fdec: FunctionDeclaration) -> JSTestFunction?
    {
        let fSignature : FunctionSignatureDeclaration = fdec.signature
        
        let fName : String = fSignature.identifier.name
        
        var jsStmts : [JSNode] = []
        
        // if this is not a test function then do not process
        if (!fName.lowercased().contains("test"))
        {
            return nil
        }
        
        let body : [Statement] = fdec.body
        
        for stmt in body {
            switch (stmt) {
            case .expression(let expr):
                jsStmts.append(process_expr(expr: expr))
            default:
                continue
            }
        }
        
        return JSTestFunction(name: fName, stmts: jsStmts)
    }
    
    
    private func process_func_call_args(args : [FunctionArgument]) -> [JSNode] {
        
        var jsArgs : [JSNode] = []
        
        for a in args {
            // create a JSNode for each of these but for now we will just do variables
            switch (a.expression)
            {
            case .identifier(let i):
                jsArgs.append(.Variable(JSVariable(variable: i.name)))
            // this should process literals and extract values from literals
            case .literal(let l):
                switch (l.kind) {
                case .literal(let lit):
                    switch (lit) {
                    case .decimal(let dec):
                        switch (dec) {
                        case .integer(let val):
                            jsArgs.append(.Literal(.Integer(val)))
                        default:
                            break
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
        
        return jsArgs
    }

    private func process_assignment_expr(binExp : BinaryExpression) -> JSNode
    {
        var rhsNode : JSNode? = nil
        var type : Bool? = nil
        var name: String? = nil
        
        var isInstantiation : Bool = false
      
        
        switch (binExp.lhs) {
        case .variableDeclaration(let vdec):
            name = vdec.identifier.name
            type = vdec.isConstant
        default:
            break
        }
        
        // we need to do function call
        switch (binExp.rhs) {
        case .binaryExpression(let binExpr):
            switch (binExpr.op.kind) {
            case .punctuation(let p):
                switch (p) {
                case .dot:
                    rhsNode = process_dot_expr(binExpr: binExpr)
                default:
                    break
                }
            default:
                break
            }
        case .functionCall(let fCall):
            isInstantiation = !fCall.identifier.name.lowercased().contains("assert") && !contractFunctionNames.contains(fCall.identifier.name)
            rhsNode = process_func_call(fCall: fCall)
        default:
            break
        }

    
        return .VariableAssignment(JSVariableAssignment(lhs: name!, rhs: rhsNode!, isConstant: type!, isInstantiation: isInstantiation))
    }
    
    private func process_dot_expr(binExpr : BinaryExpression) -> JSNode {
        var lhsName : String = ""
        var rhsNode : JSNode? = nil
        
        switch (binExpr.lhs) {
        case .identifier(let i):
            lhsName = i.name
        default:
            break
        }
        
        switch (binExpr.rhs) {
        case .functionCall(let fCall):
            rhsNode = process_func_call(fCall: fCall, lhsName: lhsName)
        default:
            break
        }
        
        return rhsNode!
    }
    
    private func process_func_call(fCall : FunctionCall, lhsName: String = "") -> JSNode {
        let fName : String = fCall.identifier.name
        let funcArgs = process_func_call_args(args: fCall.arguments)
        var isTransaction = false
        
        if let isFuncTransaction = isFuncTransaction[fName] {
            isTransaction = isFuncTransaction
        }
        
        let isAssert = fName.lowercased().contains("assert")
        
        return .FunctionCall(JSFunctionCall(contractCall: contractFunctionNames.contains(fName), transactionMethod: isTransaction, isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs))
    }
    
    
    private func process_expr(expr : Expression) -> JSNode
    {
        var jsNode : JSNode? = nil
        switch (expr) {
        case .binaryExpression(let binExp):
            switch (binExp.op.kind) {
            case .punctuation(let punc):
                switch (punc) {
                case .equal:
                    jsNode = process_assignment_expr(binExp: binExp)
                case .dot:
                    jsNode = process_dot_expr(binExpr: binExp)
                default:
                    break
                }
            default: break
            }
        case .functionCall(let fCall):
            jsNode = process_func_call(fCall: fCall)
        default:
            break
        }
        
        return jsNode!
    }
    
    
    
    private func processContract(contract : ContractDeclaration)
    {
        let members : [ContractMember] = contract.members
        
        for m in members {
            switch (m)
            {
            case .variableDeclaration(let vdec):
                process_contract_vars(vdec: vdec)
            default:
                continue
            }
        }
    }
    
    private func getStringFromExpr(expr : Expression) -> String {
        var fileName : String = ""
        switch (expr) {
        case .literal(let t):
            switch (t.kind) {
            case .literal(let lit):
                switch (lit) {
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
    
    private func process_contract_vars(vdec : VariableDeclaration) {
        let nameOfVar : String = vdec.identifier.name
        
        if (nameOfVar == "filePath") {
            self.filePath = getStringFromExpr(expr: vdec.assignedExpression!)
        } else if (nameOfVar == "contractName") {
            self.contractName = getStringFromExpr(expr: vdec.assignedExpression!)
            
        } else if (nameOfVar == "TestSuiteName") {
            self.testSuiteName = getStringFromExpr(expr: vdec.assignedExpression!)
        }
    }
    
    // this is the function that generates the string representation of the JS file -> ready for execution
    public func genFile() -> String {
        return "empty file"
    }
}
