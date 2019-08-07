//
// Created by matthewross on 7/08/19.
//

import Foundation
import AST
import MoveIR

/// Generates code for a contract initializer.
struct MoveStructInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [AST.VariableDeclaration]

  var environment: Environment

  var `struct`: MoveStruct

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: true)

    return initializerDeclaration.explicitParameters.map {
      MoveIdentifier(identifier: $0.identifier).rendered(functionContext: fc).description
    }
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return initializerDeclaration.explicitParameters.map { CanonicalType(from: $0.type.rawType,
                                                                         environment: environment)! }
  }

  /// The function's parameters and caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return ScopeContext(parameters: initializerDeclaration.signature.parameters, localVariables: [])
  }

  func rendered() -> String {
    let parameters = zip(parameterNames, parameterCanonicalTypes).map { param in
      let (name, type): (String, CanonicalType) = param
      return "\(name): \(type)"
    }.joined(separator: ", ")

    let body = MoveStructInitializerBody(
        declaration: initializerDeclaration,
        typeIdentifier: typeIdentifier,
        environment: environment,
        properties: `struct`.structDeclaration.variableDeclarations
    ).rendered()

    let moveType = CanonicalType(
        from: AST.Type(identifier: `struct`.structDeclaration.identifier).rawType,
        environment: environment
    )?.irType.description ?? "V#Self.\(`struct`.structDeclaration.identifier.name)"

    return """
           new_\(typeIdentifier.name)(\(parameters)): \(moveType) {
             \(body.indented(by: 2))
           }
           """
  }
}

struct MoveStructInitializerBody {
  var declaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  var environment: Environment
  let properties: [AST.VariableDeclaration]

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return declaration.scopeContext
  }

  init(declaration: SpecialDeclaration,
       typeIdentifier: AST.Identifier,
       environment: Environment,
       properties: [AST.VariableDeclaration]) {
    self.declaration = declaration
    self.typeIdentifier = typeIdentifier
    self.environment = environment
    self.properties = properties
  }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isConstructor: true)
    return renderBody(declaration.body, functionContext: functionContext)
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
      where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var declarations = self.properties
    var statements = statements

    while !declarations.isEmpty {
      let property: AST.VariableDeclaration = declarations.removeFirst()
      functionContext.emit(.expression(.variableDeclaration(
          MoveIR.VariableDeclaration((
                                         property.identifier.name.mangled,
                                         CanonicalType(from: property.type.rawType, environment: environment)!.irType
                                     ), nil)
      )))
    }

    while !statements.isEmpty {
      let statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    functionContext.emit(.return(.structConstructor(MoveIR.StructConstructor(
        typeIdentifier.name,
        Dictionary(uniqueKeysWithValues: properties.map {
          ($0.identifier.name, .identifier($0.identifier.name.mangled))
        })
    ))))
    return functionContext.finalise()
  }

}