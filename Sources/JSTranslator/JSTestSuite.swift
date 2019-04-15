import AST

public class JSTestSuite {
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private var JSTestFuncs: [JSTestFunction]
    
    // creates the JSTestSuite class
    public init() {
        contractName = ""
        filePath = ""
        testSuiteName = ""
        JSTestFuncs = []
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
