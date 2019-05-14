import AST

public class CoverageProvider {
    private var executableStatementCount : Int = 0
    private var functionsCount : Int = 0
    private var branchNumberCount : Int = 0
    
    public init() {}
    
    public func instrument(ast : TopLevelModule) -> TopLevelModule {
        var new_decs : [TopLevelDeclaration] = []
        
        for dec in ast.declarations {
            switch (dec) {
            case .contractDeclaration(let cdec):
                new_decs.append(.contractDeclaration(instrument_contract_dec(cdec: cdec)))
            case .contractBehaviorDeclaration(let cbdec):
                new_decs.append(.contractBehaviorDeclaration(instrument_contract_b_dec(cBdec: cbdec)))
            default:
                new_decs.append(dec)
            }
        }
     
        return TopLevelModule(declarations: new_decs)
    }
    
    private func instrument_contract_dec(cdec: ContractDeclaration) -> ContractDeclaration {
        return cdec
    }
    
    private func instrument_contract_b_dec(cBdec: ContractBehaviorDeclaration) -> ContractBehaviorDeclaration {
        return cBdec
    }

}
