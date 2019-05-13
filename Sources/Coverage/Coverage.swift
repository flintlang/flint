import AST

public class CoverageProvider {
    private var executableStatementCount : Int = 0
    private var functionsCount : Int = 0
    private var branchNumberCount : Int = 0
    
    public init() {}
    
    public func instrument(ast : TopLevelModule) -> TopLevelModule {
     
        return ast
    }

}
