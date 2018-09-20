//
//  SpecialDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of the signature of an initializer or fallback
public struct SpecialSignatureDeclaration: ASTNode {
  public var specialToken: Token

  /// The attributes associated with the function, such as `@payable`
  public var attributes: [Attribute]

  /// The modifiers associated with the function, such as `public`.
  public var modifiers: [Token]
  public var parameters: [Parameter]
  public var closeBracketToken: Token

  public var isInit: Bool {
    return specialToken.kind == .init
  }
  public var isFallback: Bool {
    return specialToken.kind == .fallback
  }

  /// The non-implicit parameters of the initializer.
  public var explicitParameters: [Parameter] {
    return asFunctionSignatureDeclaration.explicitParameters
  }

  /// A function signature declaration equivalent of the initializer.
  public var asFunctionSignatureDeclaration: FunctionSignatureDeclaration {
    let dummyIdentifier = Identifier(
      identifierToken: Token(kind: .identifier(specialToken.kind.description),
      sourceLocation: specialToken.sourceLocation)
    )

    return FunctionSignatureDeclaration(
      funcToken: specialToken,
      attributes: attributes,
      modifiers: modifiers,
      identifier: dummyIdentifier,
      parameters: parameters,
      closeBracketToken: closeBracketToken,
      resultType: nil
    )
  }

  public var isPublic: Bool {
    return asFunctionSignatureDeclaration.isPublic
  }

  public init(specialToken: Token, attributes: [Attribute], modifiers: [Token], parameters: [Parameter], closeBracketToken: Token) {
    self.specialToken = specialToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(specialToken, to: closeBracketToken)
  }

  public var description: String {
    let modifierText = modifiers.map({ $0.description }).joined(separator: " ")
    let paramText = parameters.map({ $0.description }).joined(separator: ", ")
    return "\(modifierText) \(specialToken)(\(paramText))"
  }
}

/// The declaration of an initializer or fallback
public struct SpecialDeclaration: ASTNode {
  public var specialToken: Token

  /// The attributes associated with the function, such as `@payable`.
  public var attributes: [Attribute]

  /// The modifiers associted with the function, such as `public`.
  public var modifiers: [Token]
  public var parameters: [Parameter]
  public var closeBracketToken: Token
  public var body: [Statement]
  public var closeBraceToken: Token

  public var isInit: Bool {
    return specialToken.kind == .init
  }
  public var isFallback: Bool {
    return specialToken.kind == .fallback
  }

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext

  /// The non-implicit parameters of the initializer.
  public var explicitParameters: [Parameter] {
    return asFunctionDeclaration.explicitParameters
  }

  /// A function declaration equivalent of the initializer.
  public var asFunctionDeclaration: FunctionDeclaration {
    let dummyIdentifier = Identifier(
      identifierToken: Token(kind: .identifier(specialToken.kind.description),
      sourceLocation: specialToken.sourceLocation)
    )

    return FunctionDeclaration(
      funcToken: specialToken,
      attributes: attributes,
      modifiers: modifiers,
      identifier: dummyIdentifier,
      parameters: parameters,
      closeBracketToken: closeBracketToken,
      resultType: nil,
      body: body,
      closeBraceToken: closeBracketToken,
      scopeContext: scopeContext
    )
  }

  public var isPublic: Bool {
    return asFunctionDeclaration.isPublic
  }

  public init(specialToken: Token, attributes: [Attribute], modifiers: [Token], parameters: [Parameter], closeBracketToken: Token, body: [Statement], closeBraceToken: Token, scopeContext: ScopeContext = ScopeContext()) {
    self.specialToken = specialToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
  }

  public init(_ functionDeclaration: FunctionDeclaration) {
    self.specialToken = functionDeclaration.funcToken
    self.attributes = functionDeclaration.attributes
    self.modifiers = functionDeclaration.modifiers
    self.parameters = functionDeclaration.parameters
    self.closeBracketToken = functionDeclaration.closeBracketToken
    self.body = functionDeclaration.body
    self.closeBraceToken = functionDeclaration.closeBracketToken
    self.scopeContext = functionDeclaration.scopeContext ?? ScopeContext()
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(specialToken, to: closeBracketToken)
  }

  public var description: String {
    let modifierText = modifiers.map({ $0.description }).joined(separator: " ")
    let paramText = parameters.map({ $0.description }).joined(separator: ", ")
    let headText = "\(modifierText) \(specialToken)(\(paramText))"
    let bodyText = body.map({ $0.description }).joined(separator: "\n")
    return "\(headText) {\(bodyText)}"
  }
}
