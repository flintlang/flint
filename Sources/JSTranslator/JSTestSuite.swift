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
                print(contractDec)
            case .contractBehaviorDeclaration(let contractBehaviour):
                print(contractBehaviour)
            default:
                continue
            }
        }
        
        
    }
    
    // this is the function that generates the string representation of the JS file -> ready for execution
    public func genFile() -> String {
        return "empty file"
    }
}
