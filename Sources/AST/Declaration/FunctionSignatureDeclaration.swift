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

  public var isMutating: Bool {
    return hasModifier(kind: .mutating)
  }

  public var isPayable: Bool {
    return attributes.contains { $0.kind == .payable }
  }

  public var isVoid: Bool {
    return resultType == nil || resultType?.rawType == .basicType(.void)
  }

  /// The first parameter which is both `implicit` and has a currency type.
  public var firstPayableValueParameter: Parameter? {
    return parameters.first { $0.isPayableValueParameter }
  }

  /// The non-implicit parameters of the function.
  public var explicitParameters: [Parameter] {
    return parameters.filter { !$0.isImplicit }
  }

  public var mutatingToken: Token {
    return modifiers.first { $0.kind == .mutating }!
  }

  public var isPublic: Bool {
    return hasModifier(kind: .public)
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

  private func hasModifier(kind: Token.Kind) -> Bool {
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
