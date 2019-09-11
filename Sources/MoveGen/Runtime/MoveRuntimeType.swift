//
//  MoveRuntimeFunction.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import MoveIR

/// The runtime Move types used by Flint.
enum MoveRuntimeType {
  static let imports: [Statement] = []
  static let importsWithStdlib: [Statement] = [.import(ModuleImport(name: "LibraCoin", address: "0x0"))]
  static var allImports: [Statement] = imports

  static let declarations: [String] = []
  static let declarationsWithStdlib: [String] = [
    MoveRuntimeTypeDeclaration.libra
  ]
  static var allDeclarations: [String] = declarations

  static func includeStdlib() {
    allDeclarations += declarationsWithStdlib
    allImports += importsWithStdlib
  }
}

struct MoveRuntimeTypeDeclaration {
  // See MoveRuntimeFunctionDeclaration for resource methods
  static let libra =
      """
      resource FlintLibraInternalWrapper_ {
        coin: LibraCoin.T
      }
      """
}
