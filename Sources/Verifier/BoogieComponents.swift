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

/*
enum VerificationFailureExplanation: String {
  case assertionFailure = "Could not verify assertion holds"
  case preConditionFailure = "Could not verify pre-condition holds"
  case postConditionFailure = "Could not verify post-condition is satisfied"
  case invariantFailure = "Could not verify invariant holds"

  case outOfBoundsAccess = "This could be an out of bounds access"
}
*/

enum SymbooglixError {
  case error()
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

struct TranslationInformation {
  let sourceLocation: SourceLocation
  //let verificationFailureExplanation: VerificationFailureExplanation?
}

func getMark(_ sourceLocation: SourceLocation) -> ErrorMappingKey {
  return ErrorMappingKey(file: sourceLocation.file.absoluteString,
                            flintLine: sourceLocation.line,
                            column: sourceLocation.column)
}

struct FlintProofObligationInformation {

}

struct FlintBoogieTranslation: CustomStringConvertible {
  let boogieTlds: [BTopLevelDeclaration]
  let holisticTestProcedures: [BTopLevelDeclaration]
  let holisticTestEntryPoints: [String]
  let lineMapping: [Int: TranslationInformation]

  var verificationProgram: BTopLevelProgram {
    return BTopLevelProgram(declarations: boogieTlds)
  }

  var holisticProgram: BTopLevelProgram {
    return BTopLevelProgram(declarations: boogieTlds + holisticTestProcedures)
  }

  var description: String {
    return verificationProgram.description
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
