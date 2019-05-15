import AST
import Parser
import Lexer

public class CoverageProvider {
    private var executableStatementCount : Int = 0
    private var functionsCount : Int = 0
    private var branchNumberCount : Int = 0
    private var statementCount : Int = 0
    private var blockNum : Int = 0
    
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
        
       let line = Parameter(identifier: Identifier(name: "line", sourceLocation: .DUMMY), type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)), implicitToken: nil, assignedExpression: nil)
        
        var stmVarDecs : [Parameter] = []
        stmVarDecs.append(line)
        let eventToken : Token = Token(kind: .event, sourceLocation: .DUMMY)
        let stmtEventDec : EventDeclaration = EventDeclaration(eventToken: eventToken, identifier: Identifier(name: "stmC", sourceLocation: .DUMMY), parameters: stmVarDecs)
        let stmtEvent : ContractMember = .eventDeclaration(stmtEventDec)
        
        var fncParDecs : [Parameter] = []
        fncParDecs.append(line)
        let fName = Parameter(identifier: Identifier(name: "fName", sourceLocation: .DUMMY), type: Type(identifier: Identifier(name: "String", sourceLocation: .DUMMY)), implicitToken: nil, assignedExpression: nil)
        fncParDecs.append(fName)
        let fncEventDec : EventDeclaration = EventDeclaration(eventToken: eventToken, identifier: Identifier(name: "funcC", sourceLocation: .DUMMY), parameters: fncParDecs)
        let fncEvent : ContractMember = .eventDeclaration(fncEventDec)
        
        var branchParDecs : [Parameter] = []
        branchParDecs.append(line)
        let branchNum = Parameter(identifier: Identifier(name: "branch", sourceLocation: .DUMMY), type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)), implicitToken: nil, assignedExpression: nil)
        let blockNum = Parameter(identifier: Identifier(name: "blockNum", sourceLocation: .DUMMY), type: Type(identifier: Identifier(name: "Int", sourceLocation: .DUMMY)), implicitToken: nil, assignedExpression: nil)
        branchParDecs.append(branchNum)
        branchParDecs.append(blockNum)
        
        let branchEventDec : EventDeclaration = EventDeclaration(eventToken: eventToken, identifier: Identifier(name: "branchC", sourceLocation: .DUMMY), parameters: branchParDecs)
        let branchEvent : ContractMember = .eventDeclaration(branchEventDec)
        
        var members : [ContractMember] = []
        
        members.append(branchEvent)
        members.append(fncEvent)
        members.append(stmtEvent)
        members.append(contentsOf: cdec.members)
        
        return ContractDeclaration(contractToken: cdec.contractToken, identifier: cdec.identifier, conformances: cdec.conformances, states: cdec.states, members: members)
    }
    
    private func instrument_contract_b_dec(cBdec: ContractBehaviorDeclaration) -> ContractBehaviorDeclaration {
        var members : [ContractBehaviorMember] = []
    
        for mem in cBdec.members {
            switch (mem) {
            case .functionDeclaration(let fdec):
                members.append(.functionDeclaration(instrument_function(fDec: fdec)))
            default:
                members.append(mem)
            }
        }
        
        return ContractBehaviorDeclaration(contractIdentifier: cBdec.contractIdentifier, states: cBdec.states, callerBinding: cBdec.callerBinding, callerProtections: cBdec.callerProtections, closeBracketToken: cBdec.closeBracketToken, members: members)
    }
    
    private func instrument_function(fDec: FunctionDeclaration) -> FunctionDeclaration {
        return fDec
    }

}
