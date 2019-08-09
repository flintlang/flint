//
//  IRPreprocessor.swift
//  IRGen
//
//  Created by Franklin Schrans on 2/1/18.
//

import AST

import Foundation
import Source
import Lexer

/// A preprocessing step to update the program's AST before code generation.
public struct IRPreprocessor: ASTPass {

  public init() {}

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    var structMember = structMember

    if case .specialDeclaration(var specialDeclaration) = structMember,
       specialDeclaration.isInit {
      specialDeclaration.body.insert(contentsOf: defaultValueAssignments(in: passContext), at: 0)
      // Convert the initializer to a function.
      structMember = .functionDeclaration(specialDeclaration.asFunctionDeclaration)
    }

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

    if passContext.inFunctionOrInitializer {
      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
      passContext.functionDeclarationContext?.innerDeclarations += [variableDeclaration]
      passContext.specialDeclarationContext?.innerDeclarations += [variableDeclaration]
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

    // Bind the implicit Wei value of the transaction to a variable.
    if functionDeclaration.isPayable,
       let payableParameterIdentifier = functionDeclaration.firstPayableValueParameter?.identifier {
      let weiType = Identifier(identifierToken: Token(kind: .identifier("Wei"),
                                                      sourceLocation: payableParameterIdentifier.sourceLocation))
      let variableDeclaration = VariableDeclaration(modifiers: [],
                                                    declarationToken: nil,
                                                    identifier: payableParameterIdentifier,
                                                    type: Type(identifier: weiType))
      let closeBracketToken = Token(kind: .punctuation(.closeBracket),
                                    sourceLocation: payableParameterIdentifier.sourceLocation)
      let wei = FunctionCall(identifier: weiType,
                             arguments: [
                               FunctionArgument(identifier: nil,
                                                expression: .literal(
                                                    Token(kind: .literal(.boolean(.true)),
                                                          sourceLocation: payableParameterIdentifier.sourceLocation
                                                    ))),
                               FunctionArgument(identifier: nil,
                                                expression: .rawAssembly(IRRuntimeFunction.callvalue(),
                                                                         resultType: .basicType(.int)))
                             ],
                             closeBracketToken: closeBracketToken,
                             isAttempted: false)
      let equal = Token(kind: .punctuation(.equal), sourceLocation: payableParameterIdentifier.sourceLocation)
      let assignment: Expression = .binaryExpression(
          BinaryExpression(lhs: .variableDeclaration(variableDeclaration),
                           op: equal,
                           rhs: .functionCall(wei)))
      functionDeclaration.body.insert(.expression(assignment), at: 0)
    }

    if let structDeclarationContext = passContext.structDeclarationContext {
      if Environment.globalFunctionStructName != passContext.enclosingTypeIdentifier?.name {
        // For struct functions, add `flintSelf` to the beginning of the parameters list.
        let parameter = constructParameter(
            name: "flintSelf",
            type: .inoutType(.userDefinedType(structDeclarationContext.structIdentifier.name)),
            sourceLocation: functionDeclaration.sourceLocation)
        functionDeclaration.signature.parameters.insert(parameter, at: 0)
      }
    }

    // Add an isMem parameter for each struct parameter.
    let dynamicParameters = functionDeclaration.signature.parameters.enumerated()
        .filter { $0.1.type.rawType.isDynamicType }

    var offset = 0
    for (index, parameter) in dynamicParameters where !parameter.isImplicit {
      let isMemParameter = constructParameter(name: Mangler.isMem(for: parameter.identifier.name),
                                              type: .basicType(.bool),
                                              sourceLocation: parameter.sourceLocation)
      functionDeclaration.signature.parameters.insert(isMemParameter, at: index + 1 + offset)
      offset += 1
    }

    functionDeclaration.scopeContext?.parameters = functionDeclaration.signature.parameters

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
