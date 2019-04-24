import AST
import Foundation
import Source

enum BoogieError {
  // Verification errors
  case assertionFailure(Int) // Location of failing assertion
  case preConditionFailure(Int, Int) // Location of call; pre-condition
  case postConditionFailure(Int, Int)  // Location of function; Location of failing post
  case loopInvariantEntryFailure(Int) // Location of failing loop invariant

  // Syntax / semantic errors
  case modifiesFailure(String)
  case genericFailure(String)

  ////case callPreConditionFailure(Int, String)
  //case loopInvariantMaintenanceFailure(Int, String)
}

struct ErrorMsg {
  static let ArrayOutofBoundsAccess
    = "Potential out-of-bounds error: Could not verify that array access is within array bounds"
}

enum SymbooglixError {
  case error()
}

struct HolisticRunInfo {
  let totalRuns: Int
  let successfulRuns: Int
  let responsibleSpec: SourceLocation

  var verified: Bool {
    return totalRuns > 0 && totalRuns == successfulRuns
  }

  var failedRuns: Int {
    return totalRuns - successfulRuns
  }
}

class TranslationInformation {
  let sourceLocation: SourceLocation
  // Some pre + post conditions originally come from flint invariants
  let isInvariant: Bool
  let isExternalCall: Bool
  let failingMsg: String?
  let triggerName: String? // Name of trigger with caused this
  let relatedTI: TranslationInformation?

  init(sourceLocation: SourceLocation,
       isInvariant: Bool = false,
       isExternalCall: Bool = false,
       failingMsg: String? = nil,
       triggerName: String? = nil,
       relatedTI: TranslationInformation? = nil) {
    self.sourceLocation = sourceLocation
    self.isInvariant = isInvariant
    self.isExternalCall = isExternalCall
    self.failingMsg = failingMsg
    self.triggerName = triggerName
    self.relatedTI = relatedTI
  }

  var mark: ErrorMappingKey {
    return ErrorMappingKey(file: self.sourceLocation.file.absoluteString,
                           flintLine: sourceLocation.line,
                           column: sourceLocation.column)
  }

  struct ErrorMappingKey: Hashable, CustomStringConvertible {
    let file: String
    let flintLine: Int
    let column: Int

    var hashValue: Int {
      return file.hashValue + flintLine ^ 2 + column ^ 3
    }

    var description: String {
    return "// #MARKER# \(flintLine) \(column) \(file)"
    }

    public static var DUMMY: ErrorMappingKey {
      return ErrorMappingKey(file: "", flintLine: -1, column: 0)
    }
  }
}

struct FlintProofObligationInformation {

}

struct FlintBoogieTranslation {
  let boogieTlds: [BTopLevelDeclaration]
  // List of holistic test procedures and their expression
  let holisticTestProcedures: [(SourceLocation, BTopLevelDeclaration)]
  let holisticTestEntryPoints: [String]

  var functionalProgram: BTopLevelProgram {
    return BTopLevelProgram(declarations: boogieTlds)
  }

  var holisticPrograms: [(SourceLocation, BTopLevelProgram)] {
    return holisticTestProcedures.map({ ($0.0, BTopLevelProgram(declarations: boogieTlds + [$0.1])) })
  }
}

public struct IdentifierNormaliser {
  public init() {}

  func translateGlobalIdentifierName(_ name: String, tld owningTld: String) -> String {
    return "\(name)_\(owningTld)"
  }

  func generateStateVariable(_ contractName: String) -> String {
    return translateGlobalIdentifierName("stateVariable", tld: contractName)
  }

  func generateStructInstanceVariable(structName: String) -> String {
    return translateGlobalIdentifierName("nextInstance", tld: structName)
  }

  func getShadowArraySizePrefix(depth: Int) -> String {
    return "size_\(depth)_"
  }

  func getShadowDictionaryKeysPrefix(depth: Int) -> String {
    return "keys_\(depth)_"
  }

  func getFunctionName(function: ContractBehaviorMember, tld: String) -> String {
    var functionName: String
    let parameterTypes: [RawType]
    switch function {
    case .functionDeclaration(let functionDeclaration):
      functionName = functionDeclaration.signature.identifier.name
      parameterTypes = functionDeclaration.signature.parameters.map({ $0.type.rawType })
    case .specialDeclaration(let specialDeclaration):
      functionName = specialDeclaration.signature.specialToken.description
      parameterTypes = specialDeclaration.signature.parameters.map({ $0.type.rawType })
    case .functionSignatureDeclaration(let functionSignatureDeclaration):
      functionName = functionSignatureDeclaration.identifier.name
      parameterTypes = functionSignatureDeclaration.parameters.map({ $0.type.rawType })
    case .specialSignatureDeclaration(let specialSignatureDeclaration):
      functionName = specialSignatureDeclaration.specialToken.description
      parameterTypes = specialSignatureDeclaration.parameters.map({ $0.type.rawType })
    }

    let flattenType = flattenTypes(types: parameterTypes)
    return translateGlobalIdentifierName(functionName + flattenType, tld: tld)
  }

  func flattenTypes(types: [RawType]) -> String {
    if types.count == 0 {
      return ""
    }
    var types = types
    let type = types.remove(at: 0)
    switch type {
    case .arrayType(let elemType):
      return "$\(flattenTypes(types: [elemType]))$"
    case .dictionaryType(let keyType, let valueType):
      return "@\(flattenTypes(types: [keyType]))@$@\(flattenTypes(types: [valueType]))@"
    default:
      return type.name + flattenTypes(types: types)
    }
  }
}
