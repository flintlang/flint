//
//  MoveRuntimeFunction.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import AST
import MoveIR

/// The runtime functions used by Flint.
enum MoveRuntimeFunction {
  enum Identifiers {
    case send
    case fatalError
    case power
    case revertIfGreater

    var mangled: String {
      return "\(Environment.runtimeFunctionPrefix)\(self)"
    }
  }

  static func fatalError() -> String {
    return "\(Identifiers.fatalError.mangled)()"
  }

  static func power(b: MoveIR.Expression, e: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.power.mangled, b, e))
  }

  static func revertIfGreater(value: MoveIR.Expression, max: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.revertIfGreater.mangled, value, max))
  }

  static let allDeclarations: [String] = [
    MoveRuntimeFunctionDeclaration.send,
    MoveRuntimeFunctionDeclaration.fatalError,
    MoveRuntimeFunctionDeclaration.power,
    MoveRuntimeFunctionDeclaration.revertIfGreater
  ]
}

struct MoveRuntimeFunctionDeclaration {

  static let send =
  """
  flint$send(_value: R#LibraCoin.T, _address: address) {
    LibraAccount.deposit(move(_address), move(_value));
  }
  """

  static let fatalError =
  """
  flint$fatalError() {
    assert(false, 1);
  }
  """

  static let power =
  """
  flint$power(b: u64, e: u64): u64 {
    let res: u64;
    let i: u64;

    res = 1;
    i = 0;
    while (i < e) {
      res = res * b;
      i = i + 1;
    }
    return result;
  }
  """

  // Ensure that a <= b
  static let revertIfGreater =
  """
  flint$revertIfGreater(a: u64, b: u64): u64 {
    assert(a <= b, 1);
    return a;
  }
  """
}
