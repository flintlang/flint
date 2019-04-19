import Source

struct BoogieTranslationIR {
  let tlds: [BIRTopLevelDeclaration]
  let holisticTestProcedures: [BIRTopLevelDeclaration]
  let holisticTestEntryPoints: [String]

  let lineMapping: [VerifierMappingKey: SourceLocation]
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

struct BIRProcedureDeclaration {
  let name: String
  let returnType: BType?
  let returnName: String?
  let parameters: [BParameterDeclaration]
  let prePostConditions: [BProofObligation]
  let modifies: Set<BIRModifiesDeclaration>
  let statements: [BStatement]
  let variables: Set<BVariableDeclaration>
  let mark: VerifierMappingKey
}
