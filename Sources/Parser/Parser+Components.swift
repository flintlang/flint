//
//  Parser+Components.swift
//  Parser
//
//  Created by Hails, Daniel R on 03/09/2018.
//

import AST
import Lexer

extension Parser {
  // MARK: Identifier
  func parseIdentifier() throws -> Identifier {
    guard let token = currentToken else {
      throw raise(.expectedIdentifier(at: latestSource))
    }
    switch token.kind {
      case .identifier(_), .self:
        currentIndex += 1
        consumeNewLines()
        return Identifier(identifierToken: token)
      default:
        throw raise(.expectedIdentifier(at: latestSource))
    }

  }

  func parseIdentifierGroup() throws -> (identifiers: [Identifier], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket), or: .badDeclaration(at: latestSource))
    guard let closingIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }
    let identifiers = try parseIdentifierList(upTo: closingIndex)
    let closeBracketToken = try consume(.punctuation(.closeBracket), or: .expectedCloseParen(at: latestSource))

    return (identifiers, closeBracketToken)
  }

  func parseIdentifierList(upTo closingIndex: Int) throws -> [Identifier] {
    var identifiers = [Identifier]()
    while currentIndex < closingIndex {
      identifiers.append(try parseIdentifier())
      if currentIndex < closingIndex {
        try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))
      }
    }

    return identifiers
  }

  // MARK: Attribute
  func parseAttribute() throws -> Attribute {
    let at = try consume(.punctuation(.at), or: .expectedAttribute(at: latestSource))
    guard let token = currentToken, let attribute = Attribute(atToken: at, identifierToken: token) else {
     throw raise(.missingAttributeName(at: latestSource))
    }
    currentIndex += 1
    consumeNewLines()
    return attribute
  }

  func parseAttributes() throws -> [Attribute] {
    var attributes = [Attribute]()
    // Parse function attributes such as @payable.
    while currentToken?.kind == .punctuation(.at) {
      attributes.append(try parseAttribute())
    }
    return attributes
  }

  // MARK: Modifiers
  func parseModifiers() throws -> [Token] {
    var modifiers = [Token]()
    let modifierTokens: [Token.Kind] = [.public, .mutating, .visible]
    // Parse function modifiers.
    while let first = currentToken?.kind {
      if modifierTokens.contains(first) {
        modifiers.append(try consume(anyOf: modifierTokens, or: .expectedModifier(at: latestSource)))
      }
      else {
        break
      }
    }
    return modifiers
  }

  // MARK: Literals
  func parseLiteral() throws -> Token {
    guard let token = currentToken, case .literal(_) = token.kind else {
      throw raise(.expectedLiteral(at: latestSource))
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

  func parseArrayLiteral() throws -> ArrayLiteral {
    let openSquareBracket = try consume(.punctuation(.openSquareBracket), or: .expectedLiteral(at: latestSource))

    var elements = [Expression]()

    guard let closingIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
      throw raise(.expectedCloseSquareArrayLiteral(at: latestSource))
    }

    while currentIndex < closingIndex {
      guard let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeSquareBracket)]) else {
        throw raise(.expectedSeparator(at: latestSource))
      }
      let element = try parseExpression(upTo: elementEnd)
      elements.append(element)
      if currentIndex < closingIndex {
        try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))
      }
    }
    let closeSquareBracket = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareArrayLiteral(at: latestSource))

    return ArrayLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket)
  }

  // MARK: Parameters
  func parseParameters() throws -> ([Parameter], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket), or: .expectedParameterOpenParenthesis(at: latestSource))
    var parameters = [Parameter]()

    guard let closingIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }

    while currentIndex < closingIndex {
      var implicitToken: Token? = nil
      if currentToken?.kind == .implicit {
        implicitToken = try consume(.implicit, or: .dummy())
      }

      let identifier = try parseIdentifier()
      let typeAnnotation = try parseTypeAnnotation()

      let parameter = Parameter(identifier: identifier, type: typeAnnotation.type, implicitToken: implicitToken)
      parameters.append(parameter)
      if currentIndex < closingIndex {
        try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))
      }
    }
    let closeBracketToken = try consume(.punctuation(.closeBracket), or: .expectedParameterCloseParenthesis(at: latestSource))

    return (parameters, closeBracketToken)
  }

  // MARK: Protection
  func parseProtectionBinding() throws -> Identifier {
    let identifier = try parseIdentifier()
    try consume(.punctuation(.leftArrow), or: .expectedLeftArrow(at: latestSource))
    return identifier
  }

  func parseCallerProtectionGroup() throws -> (callerProtections: [CallerProtection], closeBracketToken: Token) {
    let (identifiers, closeBracketToken) = try parseIdentifierGroup()
    let callerProtections = identifiers.map {
      return CallerProtection(identifier: $0)
    }

    return (callerProtections, closeBracketToken)
  }

  // MARK: Conformances
  func parseConformances() throws -> [Conformance] {
    try consume(.punctuation(.colon), or: .expectedConformance(at: latestSource))
    guard let endOfConformances = indexOfFirstAtCurrentDepth([.punctuation(.openBracket), .newline, .punctuation(.openBrace)]) else {
      throw raise(.expectedConformance(at: latestSource))
    }
    let identifiers = try parseIdentifierList(upTo: endOfConformances)
    return identifiers.map { Conformance(identifier: $0) }
  }

  // MARK: Type State
  func parseTypeStateGroup() throws -> [TypeState] {
    let (identifiers, _) = try parseIdentifierGroup()
    let typeStates = identifiers.map {
      return TypeState(identifier: $0)
    }

    return typeStates
  }

  // MARK: Type
  func parseType() throws -> Type {
    if let openSquareBracketToken = attempt(try consume(.punctuation(.openSquareBracket), or: .expectedType(at: latestSource))) {
      // The type is an array type or a dictionary type.
      let keyType = try parseType()
      if attempt(try consume(.punctuation(.colon), or: .expectedColonDictionaryLiteral(at: latestSource))) != nil {
        // The type is a dictionary type.
        let valueType = try parseType()
        let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareDictionaryLiteral(at: latestSource))
        return Type(openSquareBracketToken: openSquareBracketToken, dictionaryWithKeyType: keyType, valueType: valueType, closeSquareBracketToken: closeSquareBracketToken)
      }

      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareArrayType(at: latestSource))
      return Type(openSquareBracketToken: openSquareBracketToken, arrayWithElementType: keyType, closeSquareBracketToken: closeSquareBracketToken)
    }

    if let inoutToken = attempt(try consume(.inout, or: .dummy())) {
      // The type is declared inout (valid only for function parameters).
      let type = try parseType()
      return Type(ampersandToken: inoutToken, inoutType: type)
    }

    let identifier = try parseIdentifier()
    let type = Type(identifier: identifier)

    if attempt(try consume(.punctuation(.openSquareBracket), or: .dummy())) != nil {
      // The type is a fixed-size array.

      // Get the array's size.
      let literal = try parseLiteral()

      // Ensure the literal is an integer.
      guard case .literal(.decimal(.integer(let size))) = literal.kind else {
        throw raise(.expectedIntegerInFixedArrayType(at: latestSource))
      }

      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareArrayType(at: latestSource))
      return Type(fixedSizeArrayWithElementType: type, size: size, closeSquareBracketToken: closeSquareBracketToken)
    }

    if attempt(try consume(.punctuation(.openAngledBracket), or: .dummy())) != nil {
      // The type has generic arguments.
      var genericArguments = [Type]()
      while true {
        let genericArgument = try parseType()
        genericArguments.append(genericArgument)

        // If the next token is not a comma, stop parsing generic arguments.
        if attempt(try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))) == nil {
          break
        }
      }
      try consume(.punctuation(.closeAngledBracket), or: .expectedRightChevron(in: "type", at: latestSource))
      return Type(identifier: identifier, genericArguments: genericArguments)
    }

    return type
  }

  func parseTypeAnnotation() throws -> TypeAnnotation {
    let colonToken = try consume(.punctuation(.colon), or: .expectedTypeAnnotation(at: latestSource))
    let type = try parseType()
    return TypeAnnotation(colonToken: colonToken, type: type)
  }
}
