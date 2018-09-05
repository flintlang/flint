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
    guard let token = currentToken, case .identifier(_) = token.kind else {
      throw raise(.expectedIdentifier(at: latestSource))
    }
    currentIndex += 1
    consumeNewLines()
    return Identifier(identifierToken: token)
  }

  func parseIdentifierGroup() throws -> (identifiers: [Identifier], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket), or: .badDeclaration(at: latestSource))
    let identifiers = try parseIdentifierList()
    let closeBracketToken = try consume(.punctuation(.closeBracket), or: .expectedCloseParen(at: latestSource))

    return (identifiers, closeBracketToken)
  }

  func parseIdentifierList() throws -> [Identifier] {
    var identifiers = [Identifier]()
    repeat {
      identifiers.append(try parseIdentifier())
    } while attempt(try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))) != nil

    return identifiers
  }

  // MARK: Attribute
  func parseAttribute() throws -> Attribute {
    let at = try consume(.punctuation(.at), or: .expectedAttribute(at: latestSource))
    guard let token = currentToken, let attribute = Attribute(atToken: at, identifierToken: token) else {
     throw raise(.expectedIdentifier(at: latestSource))
    }
    currentIndex += 1
    consumeNewLines()
    return attribute
  }

  func parseAttributes() throws -> [Attribute] {
    var attributes = [Attribute]()
    // Parse function attributes such as @payable.
    while let attribute = attempt(parseAttribute) {
      attributes.append(attribute)
    }
    return attributes
  }

  // MARK: Modifiers
  func parseModifiers() throws -> [Token] {
    var modifiers = [Token]()
    // Parse function modifiers.
    while let token = attempt(try consume(anyOf: [.public, .mutating, .visible], or: .dummy())) {
      modifiers.append(token)
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

    var closeSquareBracket: Token?

    while let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeSquareBracket)]) {
      if let element = attempt(try parseExpression(upTo: elementEnd)) {
        let token = try consume(tokens[elementEnd].kind, or: .expectedSeparator(at: latestSource))
        if token.kind == .punctuation(.closeSquareBracket) { closeSquareBracket = token }
        elements.append(element)
      } else {
        break
      }
    }

    if elements.isEmpty {
      closeSquareBracket = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareArrayLiteral(at: latestSource))
    }

    return ArrayLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
  }

  // MARK: Parameters
  func parseParameters() throws -> ([Parameter], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket), or: .expectedParameterOpenParenthesis(at: latestSource))
    var parameters = [Parameter]()

    if let closeBracketToken = attempt(try consume(.punctuation(.closeBracket), or: .expectedParameterCloseParenthesis(at: latestSource))) {
      return ([], closeBracketToken)
    }

    // Parse parameter declarations while the next token is a comma.
    repeat {
      let implicitToken = attempt(try consume(.implicit, or: .dummy()))
      let identifier = try parseIdentifier()
      let typeAnnotation = try parseTypeAnnotation()
      parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type, implicitToken: implicitToken))
    } while attempt(try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))) != nil

    let closeBracketToken = try consume(.punctuation(.closeBracket), or: .expectedCloseParen(at: latestSource))
    return (parameters, closeBracketToken)
  }

  // MARK: Capability
  func parseCapabilityBinding() throws -> Identifier {
    let identifier = try parseIdentifier()
    try consume(.punctuation(.leftArrow), or: .expectedLeftArrow(at: latestSource))
    return identifier
  }

  func parseCallerCapabilityGroup() throws -> (callerCapabilities: [CallerCapability], closeBracketToken: Token) {
    let (identifiers, closeBracketToken) = try parseIdentifierGroup()
    let callerCapabilities = identifiers.map {
      return CallerCapability(identifier: $0)
    }

    return (callerCapabilities, closeBracketToken)
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
