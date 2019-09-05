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
    case withdrawAll
    case transfer

    var mangled: String {
      return "Self.\(Environment.runtimeFunctionPrefix)\(self)"
    }
  }

  static func fatalError() -> String {
    return "\(Identifiers.fatalError.mangled)()"
  }

  static func withdrawAll(source: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.withdrawAll.mangled, source))
  }

  static func transfer(destination: MoveIR.Expression,
                       source: MoveIR.Expression,
                       amount: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.transfer.mangled, destination, source, amount))
  }

  static func power(b: MoveIR.Expression, e: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.power.mangled, b, e))
  }

  static func revertIfGreater(value: MoveIR.Expression, max: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.revertIfGreater.mangled, value, max))
  }

  static let allDeclarations: [String] = [
    // Not currently available as no money yet: MoveRuntimeFunctionDeclaration.send,
    //MoveRuntimeFunctionDeclaration.send,
    //MoveRuntimeFunctionDeclaration.withdrawAll,
    //MoveRuntimeFunctionDeclaration.transfer,
    MoveRuntimeFunctionDeclaration.fatalError,
    MoveRuntimeFunctionDeclaration.power,
    MoveRuntimeFunctionDeclaration.revertIfGreater,
    MoveRuntimeFunctionDeclaration.libra
  ]
}

struct MoveRuntimeFunctionDeclaration {

  static let send =
  """
  flint$send(money: &mut LibraCoin.T, addr: address) {
    LibraAccount.deposit(move(addr), flint$withdrawAll(move(money)));
    return;
  }
  """

  static let withdrawAll =
  """
  flint$withdrawAll(source: &mut LibraCoin.T): LibraCoin.T {
    let coin_value: u64;
    let ret: LibraCoin.T;
    coin_value = LibraCoin.value(freeze(copy(coin_ref)));
    ret = LibraCoin.withdraw(copy(coin_ref), copy(coin_value));
    _ = move(coin_ref));
    return move(ret);
  }
  """

  // TODO Import LibraCoin within the produced module
  static let transfer =
  """
  flint$transfer(destination: &mut LibraCoin.T, source: &mut LibraCoin.T, amount: u64) {
    let desposit: LibraCoin.T;
    deposit = LibraCoin.withdraw(move(source), copy(amount));
    LibraCoin.deposit(move(destination), move(deposit));
    return;
  }
  """

  static let fatalError =
  """
  flint$fatalError() {
    assert(false, 1);
    return;
  }
  """

  static let power =
  """
  flint$power(b: u64, e: u64): u64 {
    let res: u64;
    let i: u64;

    res = 1;
    i = 0;
    while (copy(i) < copy(e)) {
      res = copy(res) * copy(b);
      i = copy(i) + 1;
    }
    return copy(res);
  }
  """

  // Ensure that a <= b
  static let revertIfGreater =
  """
  flint$revertIfGreater(a: u64, b: u64): u64 {
    assert(copy(a) <= move(b), 1);
    return move(a);
  }
  """

  static let libra =
      """
      public Libra$new$Address(zero: address): Self.Libra {
        if (move(zero) != 0x0) {
          assert(false, 9001);
        }
        return Libra {
          coin: LibraCoin.zero()
        };
      }

      public Libra$getValue(this: &mut Self.Libra): u64 {
        let coin: &LibraCoin.T;
        coin = &move(this).coin;
        return LibraCoin.value(move(coin));
      }

      public Libra$withdraw(this: &mut Self.Libra, amount: u64): Self.Libra {
        let coin: &mut LibraCoin.T;
        coin = &mut move(this).coin;
        return Libra {
          coin: LibraCoin.withdraw(move(coin), move(amount))
        };
      }

      public Libra$transfer(this: &mut Self.Libra, other: &mut Self.Libra, amount: u64) {
        let coin: &mut LibraCoin.T;
        let other_coin: &mut LibraCoin.T;
        let temporary: LibraCoin.T;
        coin = &mut move(this).coin;
        temporary = LibraCoin.withdraw(move(coin), move(amount));
        other_coin = &mut move(other).coin;
        LibraCoin.deposit(move(other_coin), move(temporary));
        return;
      }
      """
}
