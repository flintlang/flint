//
//  SpecialSignatureDeclaration.swift
//  AST
//
//  Created by Hails, Daniel R on 07/09/2018.
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

  /// The non-implicit parameters of the initializer.
  public var explicitParameters: [Parameter] {
    return parameters.filter { !$0.isImplicit }
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
      prePostConditions: [],
      closeBracketToken: closeBracketToken,
      resultType: nil
    )
  }

  public init(specialToken: Token,
              attributes: [Attribute],
              modifiers: [Token],
              parameters: [Parameter],
              closeBracketToken: Token) {
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
