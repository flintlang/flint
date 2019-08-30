//
// Created by matthewross on 2/08/19.
//

import Foundation

public struct StructConstructor: CustomStringConvertible, Throwing {
  public let name: Identifier
  public let fields: [Identifier: Expression]

  public init(_ name: Identifier, _ fields: [Identifier: Expression]) {
    self.name = name
    self.fields = fields
  }

  public var catchableSuccesses: [Expression] {
    return fields.flatMap { argument in argument.1.catchableSuccesses }
  }

  public var description: String {
    let args = fields.map({ "\($0.0): \($0.1)"}).joined(separator: ",\n")
    return """
           \(name) {
             \(args.indented(by: 2))
           }
           """
  }
}
