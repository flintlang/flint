//
//  FunctionDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of a function.
public struct FunctionDeclaration: ASTNode {
  public var signature: FunctionSignatureDeclaration
  public var body: [Statement]
  public var closeBraceToken: Token

  public var mangledIdentifier: String?

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext?

  public init(signature: FunctionSignatureDeclaration,
              body: [Statement],
              closeBraceToken: Token,
              scopeContext: ScopeContext? = nil) {
    self.signature = signature
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
  }

  public var isMutating: Bool {
    return signature.hasModifier(kind: .mutating)
  }

  public var isPayable: Bool {
    return signature.attributes.contains { $0.kind == .payable }
  }

  public var isVoid: Bool {
    return signature.resultType == nil || signature.resultType?.rawType == .basicType(.void)
  }

  /// The first parameter which is both `implicit` and has a currency type.
  public var firstPayableValueParameter: Parameter? {
    return signature.parameters.first { $0.isPayableValueParameter }
  }

  /// The non-implicit parameters of the function.
  public var explicitParameters: [Parameter] {
    return signature.parameters.filter { !$0.isImplicit }
  }

  public var mutatingToken: Token {
    return signature.modifiers.first { $0.kind == .mutating }!
  }

  public var isPublic: Bool {
    return signature.hasModifier(kind: .public)
  }

  public var identifier: Identifier {
    return signature.identifier
  }

  public var name: String {
    return identifier.name
  }

  // MARK: - ASTNode
  public var description: String {
    let bodyText = body.map({ $0.description }).joined(separator: "\n")
    return "\(signature) {\(bodyText)}"
  }

  public var sourceLocation: SourceLocation {
    return signature.sourceLocation
  }
}
