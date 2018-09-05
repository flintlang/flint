//
//  Parser+Type.swift
//  AST
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import AST
import Lexer
import Source

extension Parser {
  func parseTypeAnnotation() throws -> TypeAnnotation {
    let colonToken = try consume(.punctuation(.colon))
    let type = try parseType()
    return TypeAnnotation(colonToken: colonToken, type: type)
  }

  func parseType() throws -> Type {
    let atomicType = try parseAtomicType()
    return try parseContainerType(atomicType, attributes: attrs)
  }

  func parseAtomicType() throws -> Type {
    if let openSquareBracketToken = attempt(try consume(.punctuation(.openSquareBracket))) {
      return try parseCollectionType()
    }
    if let anyToken = try? consume(.any) {
      return AnyType(anyToken)
    }
    if let selfToken = try? consume(.self) {
      return SelfType(selfToken)
    }

    return 
  }
}

func parseType() throws -> TypeIdentifier {
  if let openSquareBracketToken = attempt(try consume(.punctuation(.openSquareBracket))) {
    // The type is an array type or a dictionary type.
    let keyType = try parseType()
    if attempt(try consume(.punctuation(.colon))) != nil {
      // The type is a dictionary type.
      let valueType = try parseType()
      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
      return Type(openSquareBracketToken: openSquareBracketToken, dictionaryWithKeyType: keyType, valueType: valueType, closeSquareBracketToken: closeSquareBracketToken)
    }

    let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
    return Type(openSquareBracketToken: openSquareBracketToken, arrayWithElementType: keyType, closeSquareBracketToken: closeSquareBracketToken)
  }

  if let inoutToken = attempt(try consume(.inout)) {
    // The type is declared inout (valid only for function parameters).
    let type = try parseType()
    return Type(ampersandToken: inoutToken, inoutType: type)
  }

  let identifier = try parseIdentifier()
  let type = TypeIdentifier(identifier: identifier)

  if attempt(try consume(.punctuation(.openSquareBracket))) != nil {
    // The type is a fixed-size array.

    // Get the array's size.
    let literal = try parseLiteral()

    // Ensure the literal is an integer.
    guard case .literal(.decimal(.integer(let size))) = literal.kind else {
      throw ParserError.expectedToken(.literal(.decimal(.integer(0))), sourceLocation: literal.sourceLocation)
    }

    let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
    return Type(fixedSizeArrayWithElementType: type, size: size, closeSquareBracketToken: closeSquareBracketToken)
  }

  if attempt(try consume(.punctuation(.openAngledBracket))) != nil {
    // The type has generic arguments.
    var genericArguments = [Type]()
    while true {
      let genericArgument = try parseType()
      genericArguments.append(genericArgument)

      // If the next token is not a comma, stop parsing generic arguments.
      if attempt(try consume(.punctuation(.comma))) == nil {
        break
      }
    }
    try consume(.punctuation(.closeAngledBracket))
    return TypeIdentifier(identifier: identifier, genericArguments: genericArguments)
  }

  return type
}


