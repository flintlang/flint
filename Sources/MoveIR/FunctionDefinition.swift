//
//  FunctionDefinition.swift
//  YUL
//
//

public struct FunctionDefinition: CustomStringConvertible {
  public let identifier: Identifier
  public let arguments: [TypedIdentifier]
  public let returns: [TypedIdentifier]
  public let body: Block

  public init(identifier: Identifier,
              arguments: [TypedIdentifier],
              returns: [TypedIdentifier] = [],
              body: Block) {
    self.identifier = identifier
    self.arguments = arguments
    self.returns = returns
    self.body = body
  }

  public var description: String {
    let args = render(typedIdentifiers: self.arguments)

    var ret = ""
    if !self.returns.isEmpty {
      let retargs = render(typedIdentifiers: self.returns)
      ret = ": \(retargs) "
    }

    return "\(self.identifier)(\(args)) \(ret)\(self.body)"
  }
}
