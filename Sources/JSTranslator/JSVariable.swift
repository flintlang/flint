public class JSVariable: CustomStringConvertible {
  private let variable: String
  private let type: String
  private let isConst: Bool

  public init(variable: String, type: String, isConstant: Bool) {
    self.variable = variable
    self.type = type
    self.isConst = isConstant
  }

  public func isConstant() -> Bool {
    return isConst
  }

  public func name() -> String {
    return variable
  }

  public func getType() -> String {
    return type
  }

  public var description: String {
    return variable
  }
}
