enum BoogieError {
  // Failure (line number, error string)

  case assertionFailure(Int, String)
  case preConditionFailure(Int, String)
  case postConditionFailure(Int, String)
  case modifiesFailure(Int, String)
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

  func getArraySizeVariableName(arrayName: String) -> String {
    return "size_\(arrayName)"
  }

  func getDictKeysVariableName(dictName: String) -> String {
    return "keys_\(dictName)"
  }
}
