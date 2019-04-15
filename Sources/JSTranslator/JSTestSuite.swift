import AST

public class JSTestSuite {
    private var contractName: String
    private var filePath: String
    private var JSTestFuncs: [JSTestFunction]
    
    // creates the JSTestSuite class
    public init() {
        contractName = ""
        filePath = ""
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
        // this function should extract out the test funcs from each of the contracts and populate the JSTestFuncs array
    }
    
    private func processContract(contract : ContractDeclaration)
    {
        // this functions duty is to extract the file path and contract name
    }
    
    // this is the function that generates the string representation of the JS file -> ready for execution
    public func genFile() -> String {
        return "empty file"
    }
}
