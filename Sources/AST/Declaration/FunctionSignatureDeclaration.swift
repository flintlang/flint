//
//  FunctionSignatureDeclaration.swift
//  AST
//
//  Created by Harkness, Alexander L on 2018-09-05.
//
import Source
import Lexer

// The declaration of a function signature.
public struct FunctionSignatureDeclaration: ASTNode {
  public var funcToken: Token

  /// The attributes associated with the function, such as `@payable`.
  public var attributes: [Attribute]

  /// The modifiers associted with the function, such as `public` or `mutating.`
  public var modifiers: [Token]
  public var identifier: Identifier
  public var parameters: [Parameter]
  public var closeBracketToken: Token
  public var resultType: Type?

  public var mangledIdentifier: String? = nil
  
  /// The raw type of the function's return type.
  public var rawType: RawType {
    return resultType?.rawType ?? .basicType(.void)
  }

  public init(funcToken: Token, attributes: [Attribute], modifiers: [Token], identifier: Identifier, parameters: [Parameter], closeBracketToken: Token, resultType: Type?) {
    self.funcToken = funcToken
    self.attributes = attributes
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.closeBracketToken = closeBracketToken
    self.resultType = resultType
  }

  func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind }
  }

  // MARK: - ASTNode
  public var description: String {
    let modifierText = modifiers.map({ $0.description }).joined(separator: " ")
    let paramText = parameters.map({ $0.description }).joined(separator: ", ")
    return "\(modifierText) func \(identifier)(\(paramText)) \(resultType == nil ? "" : "-> \(resultType!)")"
  }

  public var sourceLocation: SourceLocation {
    if let resultType = resultType {
      return .spanning(funcToken, to: resultType)
    }
    return .spanning(funcToken, to: closeBracketToken)
  }
}
