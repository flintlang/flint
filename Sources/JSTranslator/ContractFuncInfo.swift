import AST
import Parser
import Lexer

public struct ContractFuncInfo {
  private var resultType: String
  private var payable: Bool
  private var argTypes: [String]

  public init(resultType: String, payable: Bool, argTypes: [String] = []) {
    self.resultType = resultType
    self.payable = payable
    self.argTypes = argTypes
  }

  public func getArgTypes() -> [String] {
    return argTypes
  }

  public func getType() -> String {
    return resultType
  }

  public func isPayable() -> Bool {
    return payable
  }
}
