//
// Created by matthewross on 7/08/19.
//

import Foundation
import AST
import MoveIR
import Lexer

/// Generates code for a contract initializer.
struct MoveStructInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [AST.VariableDeclaration]

  var environment: Environment

  var `struct`: MoveStruct

  var moveType: MoveIR.`Type`? {
    return CanonicalType(
        from: AST.Type(identifier: typeIdentifier).rawType,
        environment: environment
    )?.irType
  }

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
    return initializerDeclaration.explicitParameters.map {
      CanonicalType(from: $0.type.rawType,
                    environment: environment)!
    }
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

    let name = Mangler.mangleInitializerName(
        typeIdentifier.name,
        parameterTypes: initializerDeclaration.explicitParameters.map { $0.type.rawType }
    )

    return """
           \(name)(\(parameters)): \(moveType?.description ?? "V#Self.\(`struct`.structDeclaration.identifier.name)") {
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

  var moveType: MoveIR.`Type`? {
    return CanonicalType(
        from: AST.Type(identifier: typeIdentifier).rawType,
        environment: environment
    )?.irType
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
                                     ))
      )))
    }

    var unassigned: [AST.Identifier] = properties.map { $0.identifier }

    while !(statements.isEmpty || unassigned.isEmpty) {
      let statement: AST.Statement = statements.removeFirst()

      if case .expression(let expression) = statement,
         case .binaryExpression(let binary) = expression,
         case .punctuation(let op) = binary.op.kind,
         case .equal = op {
        switch binary.lhs {
        case .identifier(let identifier):
          if let type = identifier.enclosingType,
             type == typeIdentifier.name {
            unassigned = unassigned.filter { $0.name != identifier.name }
          }
        case .binaryExpression(let lhs):
          if case .punctuation(let op) = lhs.op.kind,
             case .dot = op,
             case .`self` = lhs.lhs,
             case .identifier(let field) = lhs.rhs {
            unassigned = unassigned.filter { $0.name != field.name }
          }
        default: break
        }
      }
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }

    let constructor = Expression.structConstructor(StructConstructor(
        typeIdentifier.name,
        Dictionary(uniqueKeysWithValues: properties.map {
          ($0.identifier.name, .identifier($0.identifier.name.mangled))
        })
    ))

    guard !statements.isEmpty else {
      functionContext.emit(.return(constructor))
      return functionContext.finalise()
    }

    functionContext.isConstructor = false

    let selfName = MoveSelf.generate(sourceLocation: declaration.sourceLocation)
        .rendered(functionContext: functionContext).description
    functionContext.emit(
        .expression(.variableDeclaration(MoveIR.VariableDeclaration((selfName, moveType!)))),
        at: 0
    )
    functionContext.emit(.expression(.assignment(Assignment(selfName, constructor))))
    while !statements.isEmpty {
      let statement: AST.Statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    functionContext.emit(.return(
        MoveSelf.generate(sourceLocation: declaration.closeBraceToken.sourceLocation)
            .rendered(functionContext: functionContext)
    ))
    return functionContext.finalise()
  }
}
