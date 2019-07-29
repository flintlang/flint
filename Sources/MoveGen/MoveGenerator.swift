//
// Created by matthewross on 29/07/19.
//

import Foundation
import AST

public struct MoveGenerator {
  var topLevelModule: TopLevelModule
  var environment: Environment

  public init(ast topLevelModule: TopLevelModule, environment: Environment) {
    self.topLevelModule = topLevelModule
    self.environment = environment
  }

  public func generateCode() -> String {
    return ""
  }
}
