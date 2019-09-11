//
//  MoveWrapperFunction.swift
//  MoveGen
//
//

import AST

struct MoveWrapperFunction {
  static let prefix = "flintWrapper$"
  let function: MoveFunction

  func rendered(enclosingType: RawTypeIdentifier) -> String {

    return "WRAPPER"
  }

  var signature: String {
    return "\(MoveWrapperFunction.prefix)\(function.signature(withReturn: false))"
  }
}
