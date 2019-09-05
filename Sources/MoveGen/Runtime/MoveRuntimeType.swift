//
//  MoveRuntimeFunction.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import MoveIR

/// The runtime functions used by Flint.
enum MoveRuntimeType {
  static let imports: [Statement] = [.import(ModuleImport(name: "LibraCoin", address: "0x0"))]

  static let allDeclarations: [String] = [
    MoveRuntimeTypeDeclaration.libra
  ]
}

struct MoveRuntimeTypeDeclaration {
  // See MoveRuntimeFunctionDeclaration for resource methods
  static let libra =
      """
      resource Libra {
        coin: LibraCoin.T
      }
      """
}
