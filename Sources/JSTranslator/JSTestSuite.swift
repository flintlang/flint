import AST

public class JSTestSuite {
    // for now lets write this to support a single test contract
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private var JSTestFuncs: [JSTestFunction]
    
    private var isFuncTransaction : [String:Bool]
    
    // creates the JSTestSuite class
    public init() {
        contractName = ""
        filePath = ""
        testSuiteName = ""
        JSTestFuncs = []
        isFuncTransaction = [:]
    }
    
    // this function is the entry point which takes a flint AST and translates it into a JS AST suitable for testing
    public func convertAST(ast: TopLevelModule) {
        let declarations : [TopLevelDeclaration] = ast.declarations
        
        for d in declarations {
            switch d {
            case .contractDeclaration(let contractDec):
                processContract(contract: contractDec)
            case .contractBehaviorDeclaration(let contractBehaviour):
                processContractBehaviour(contractBehaviour: contractBehaviour)
            default:
                continue
            }
        }
    }
    
    private func processContractBehaviour(contractBehaviour: ContractBehaviorDeclaration)
    {
        
        let members : [ContractBehaviorMember] = contractBehaviour.members
        
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                isFuncTransaction[fdec.identifier.name] = fdec.isMutating
            default:
                continue
            }
        }
        
        // process each of the function declarations
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                print(fdec)
            default:
                continue
            }
        }
    }
    
    private func processContractFunction(fdec: FunctionDeclaration)
    {
        let fSignature : FunctionSignatureDeclaration = fdec.signature
        
        let fName : String = fSignature.identifier.name
        
        var jsStmts : [JSNode] = []
        
        // if this is not a test function then do not process
        if (!fName.lowercased().contains("test"))
        {
            return
        }
        
        let body : [Statement] = fdec.body
        
        // I should create a JS Function here
        // does this make sense
        // I should probably factor this stuff out
        for stmt in body {
            switch (stmt) {
            case .expression(let expr):
                // okay -> I need to do other stuff
                //jsStmts.append(process_expr(expr: expr))
                print(expr)
            default:
                continue
            }
        }
    }
    
    private func process_expr(expr : Expression) -> JSNode?
    {
        // writing a lot of code is tiring
        let jsNode : JSNode? = nil
        
        switch (expr) {
        case .functionCall(let fCall):
            print(fCall)
        case .binaryExpression(let binExp):
            print(binExp)
        default:
            break
        }
        
        return jsNode
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
