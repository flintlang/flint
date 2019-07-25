public struct REPLVariable {
  public let variableName: String
  public let variableType: String
  public let variableValue: String
  public let varConstant: Bool

  public init(variableName: String, variableType: String, variableValue: String, varConstant: Bool) {
    self.variableName = variableName
    self.variableType = variableType
    self.variableValue = variableValue
    self.varConstant = varConstant
  }
}
