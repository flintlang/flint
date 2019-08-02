//
//  SpecialDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of an initializer or fallback
public struct SpecialDeclaration: ASTNode {
  public var signature: SpecialSignatureDeclaration
  public var body: [Statement]
  public var closeBraceToken: Token

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext

  // Flag indicating whether this declaration is generated.
  // This is currently used for external traits where we 
  // generate an initializer.
  public var generated: Bool

  /// The non-implicit parameters of the initializer.
  public var explicitParameters: [Parameter] {
    return asFunctionDeclaration.explicitParameters
  }

  /// A function declaration equivalent of the initializer.
  public var asFunctionDeclaration: FunctionDeclaration {
    let dummyIdentifier = Identifier(
      identifierToken: Token(kind: .identifier(signature.specialToken.kind.description),
      sourceLocation: signature.specialToken.sourceLocation)
    )
    let functionSignature = FunctionSignatureDeclaration(
      funcToken: signature.specialToken,
      attributes: signature.attributes,
      modifiers: signature.modifiers,
      mutates: signature.mutates,
      identifier: dummyIdentifier,
      parameters: signature.parameters,
      prePostConditions: signature.prePostConditions,
      closeBracketToken: signature.closeBracketToken,
      resultType: nil)

    return FunctionDeclaration(signature: functionSignature,
                               body: body,
                               closeBraceToken: closeBraceToken,
                               scopeContext: scopeContext)
  }

  public var isInit: Bool {
    return signature.specialToken.kind == .init
  }
  public var isFallback: Bool {
    return signature.specialToken.kind == .fallback
  }

  public var isPublic: Bool {
    return asFunctionDeclaration.isPublic
  }

  public init(signature: SpecialSignatureDeclaration,
              body: [Statement],
              closeBraceToken: Token,
              scopeContext: ScopeContext = ScopeContext(),
              generated: Bool = false) {
    self.signature = signature
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
    self.generated = generated
  }

  public init(_ functionDeclaration: FunctionDeclaration) {
    self.signature = SpecialSignatureDeclaration(specialToken: functionDeclaration.signature.funcToken,
                                                 attributes: functionDeclaration.signature.attributes,
                                                 modifiers: functionDeclaration.signature.modifiers,
                                                 mutates: functionDeclaration.signature.mutates,
                                                 parameters: functionDeclaration.signature.parameters,
                                                 prePostConditions: functionDeclaration.signature.prePostConditions,
                                                 closeBracketToken: functionDeclaration.signature.closeBracketToken)
    self.body = functionDeclaration.body
    self.closeBraceToken = functionDeclaration.closeBraceToken
    self.scopeContext = functionDeclaration.scopeContext ?? ScopeContext()
    self.generated = false
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return signature.sourceLocation
  }

  public var description: String {
    let bodyText = body.map({ $0.description }).joined(separator: "\n")
    return "\(signature) {\(bodyText)}"
  }
}
