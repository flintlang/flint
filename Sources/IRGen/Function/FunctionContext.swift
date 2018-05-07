//
//  Context.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST

/// Context used when generating code the body of a function.
struct FunctionContext {
  /// Environment information, such as typing of variables, for the source program.
  var environment: Environment

  /// Set of local variables defined in the scope of the function, including caller capability bindings.
  var scopeContext: ScopeContext

  /// The type in which the function is declared.
  var enclosingTypeName: String

  /// Whether the function is declared in a struct.
  var isInStructFunction: Bool
}
