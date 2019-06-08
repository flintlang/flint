import Source

struct BoogieTranslationIR {
  let tlds: [BIRTopLevelDeclaration]
  let holisticTestProcedures: [(SourceLocation, [BIRTopLevelDeclaration])]
  let holisticTestEntryPoints: [String]

  let callGraph: [String: Set<String>]
}

struct BIRTopLevelProgram {
  let declarations: [BIRTopLevelDeclaration]
}

enum BIRTopLevelDeclaration {
  case functionDeclaration(BFunctionDeclaration)
  case axiomDeclaration(BAxiomDeclaration)
  case variableDeclaration(BVariableDeclaration)
  case constDeclaration(BConstDeclaration)
  case typeDeclaration(BTypeDeclaration)
  case procedureDeclaration(BIRProcedureDeclaration)
}

struct BIRModifiesDeclaration: Hashable {
  // Name of global variable being modified
  let variable: String
  let userDefined: Bool

  var hashValue: Int {
    return variable.hashValue
  }
}

struct BIRInvariant {
  let expression: BExpression
  let ti: TranslationInformation
}

struct BIRProcedureDeclaration {
  let name: String
  let returnTypes: [BType]?
  let returnNames: [String]?
  let parameters: [BParameterDeclaration]
  let preConditions: [BPreCondition]
  let postConditions: [BPostCondition]
  let structInvariants: [BIRInvariant]
  let contractInvariants: [BIRInvariant]
  let globalInvariants: [BIRInvariant]
  let modifies: Set<BIRModifiesDeclaration>
  let statements: [BStatement]
  let variables: Set<BVariableDeclaration>
  let inline: Bool
  let ti: TranslationInformation

  let isHolisticProcedure: Bool
  let isStructInit: Bool
  let isContractInit: Bool
}
