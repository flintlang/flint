//
//  MovePreprocessor.swift
//  MoveGen
//
//  Created by Franklin Schrans on 2/1/18.
//

import AST

import Foundation
import Source
import Lexer

/// A preprocessing step to update the program's AST before code generation.
public struct MovePreprocessor: ASTPass {

  public init() {}

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    var structMember = structMember

    /* if case .specialDeclaration(let specialDeclaration) = structMember,
       specialDeclaration.isInit {
      // Convert the initializer to a function.
      structMember = .functionDeclaration(specialDeclaration.asFunctionDeclaration)
    } */

    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  /// Returns assignment statements for all the properties which have been assigned default values.
  func defaultValueAssignments(in passContext: ASTPassContext) -> [Statement] {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let propertiesInEnclosingType = passContext.environment!.propertyDeclarations(in: enclosingType)

    return propertiesInEnclosingType.compactMap { declaration -> Statement? in
      guard let assignedExpression = declaration.value else { return nil }

      var identifier = declaration.identifier
      identifier.enclosingType = enclosingType

      return .expression(
          .binaryExpression(
              BinaryExpression(lhs: .identifier(identifier),
                               op: Token(kind: .punctuation(.equal), sourceLocation: identifier.sourceLocation),
                               rhs: assignedExpression)))
    }
  }

  // MARK: Declaration
  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    if passContext.functionDeclarationContext != nil {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
      passContext.functionDeclarationContext?.innerDeclarations += [variableDeclaration]
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration

    // Mangle the function name in the declaration.
    let parameters = functionDeclaration.signature.parameters.rawTypes
    let name = Mangler.mangleFunctionName(functionDeclaration.identifier.name,
                                          parameterTypes: parameters,
                                          enclosingType: passContext.enclosingTypeIdentifier!.name)
    functionDeclaration.mangledIdentifier = name

    // Bind the implicit Libra value of the transaction to a variable.
    if functionDeclaration.isPayable,
       let payableParameterIdentifier = functionDeclaration.firstPayableValueParameter?.identifier {
      let libraType = Identifier(identifierToken: Token(kind: .identifier("Libra"),
                                                      sourceLocation: payableParameterIdentifier.sourceLocation))
      let variableDeclaration = VariableDeclaration(modifiers: [],
                                                    declarationToken: nil,
                                                    identifier: payableParameterIdentifier,
                                                    type: Type(identifier: libraType))
      let closeBracketToken = Token(kind: .punctuation(.closeBracket),
                                    sourceLocation: payableParameterIdentifier.sourceLocation)
      let libra = FunctionCall(identifier: libraType,
                             arguments: [
                               FunctionArgument(identifier: nil,
                                                expression: .literal(
                                                    Token(kind: .literal(.boolean(.true)),
                                                          sourceLocation: payableParameterIdentifier.sourceLocation
                                                    ))),
                               FunctionArgument(identifier: nil,
                                                // FIXME Replace me
                                                expression: .rawAssembly(MoveRuntimeFunction.fatalError(),
                                                                         resultType: .basicType(.int)))
                             ],
                             closeBracketToken: closeBracketToken,
                             isAttempted: false)
      let equal = Token(kind: .punctuation(.equal), sourceLocation: payableParameterIdentifier.sourceLocation)
      let assignment: Expression = .binaryExpression(
          BinaryExpression(lhs: .variableDeclaration(variableDeclaration),
                           op: equal,
                           rhs: .functionCall(libra)))
      functionDeclaration.body.insert(.expression(assignment), at: 0)
    }

    if let structDeclarationContext = passContext.structDeclarationContext,
      Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
      // For struct functions, add `flintSelf` to the beginning of the parameters list.
      let parameter = constructThisParameter(
          type: .inoutType(.userDefinedType(structDeclarationContext.structIdentifier.name)),
          sourceLocation: functionDeclaration.sourceLocation)
      functionDeclaration.signature.parameters.insert(parameter, at: 0)
    } else if passContext.contractBehaviorDeclarationContext != nil,
      Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
      let identifier = Identifier(identifierToken: Token(kind: .identifier("_address_\(MoveSelf.selfName)"),
                                                         sourceLocation: functionDeclaration.sourceLocation))
      let parameter = Parameter(identifier: identifier,
                                type: Type(inferredType: .basicType(.address), identifier: identifier),
                                implicitToken: nil,
                                assignedExpression: nil)
      functionDeclaration.signature.parameters.insert(parameter, at: 0)
    }
    
    /*
     func constructThisParameter(type: RawType, sourceLocation: SourceLocation) -> Parameter {
     let identifier = Identifier(identifierToken: Token(kind: .`self`, sourceLocation: sourceLocation))
     return Parameter(identifier: identifier,
     type: Type(inferredType: type,
     identifier: identifier),
     implicitToken: nil,
     assignedExpression: nil)
     }
     */

    functionDeclaration.scopeContext?.parameters = functionDeclaration.signature.parameters

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  private func deleteDeclarations(in statements: [Statement]) -> [Statement] {
    return statements.compactMap { statement -> Statement? in
      switch statement {
      case .expression(let expression):
        if case .variableDeclaration(_) = expression {
          return nil
        }
      case .forStatement(var stmt):
        stmt.body = deleteDeclarations(in: stmt.body)
        return .forStatement(stmt)
      case .ifStatement(var stmt):
        stmt.body = deleteDeclarations(in: stmt.body)
        return .ifStatement(stmt)
      case .doCatchStatement(var stmt):
        stmt.catchBody = deleteDeclarations(in: stmt.catchBody)
        stmt.doBody = deleteDeclarations(in: stmt.doBody)
        return .doCatchStatement(stmt)
      default:
        return statement
      }
      return statement
    }
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration

    let declarations = passContext.scopeContext!.localVariables.map { declaration -> Statement in
      var declaration: VariableDeclaration = declaration
      declaration.identifier = Identifier(name: declaration.identifier.name.mangled,
                                          sourceLocation: declaration.identifier.sourceLocation)
      return Statement.expression(.variableDeclaration(declaration))
    }
    functionDeclaration.body = declarations + deleteDeclarations(in: functionDeclaration.body)
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  func constructParameter(name: String, type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: type,
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }

  func constructThisParameter(type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .`self`, sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: type,
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    // No longer neccessary since during Verifier coding someone moves this in the main AST
//    if specialDeclaration.isInit {
//      specialDeclaration.body.insert(contentsOf: defaultValueAssignments(in: passContext), at: 0)
//    }
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Statement
  public func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var becomeStatement = becomeStatement

    let enumName = ContractDeclaration.contractEnumPrefix + passContext.enclosingTypeIdentifier!.name
    let enumReference: Expression = .identifier(
        Identifier(identifierToken: Token(kind: .identifier(enumName), sourceLocation: becomeStatement.sourceLocation)))
    let state = becomeStatement.expression.assigningEnclosingType(type: enumName)

    let dot = Token(kind: .punctuation(.dot), sourceLocation: becomeStatement.sourceLocation)

    becomeStatement.expression = .binaryExpression(BinaryExpression(lhs: enumReference, op: dot, rhs: state))

    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
}

extension ASTPassContext {
  var functionCallReceiverTrail: [Expression]? {
    get { return self[FunctionCallReceiverTrailContextEntry.self] }
    set { self[FunctionCallReceiverTrailContextEntry.self] = newValue }
  }
}

struct FunctionCallReceiverTrailContextEntry: PassContextEntry {
  typealias Value = [Expression]
}
