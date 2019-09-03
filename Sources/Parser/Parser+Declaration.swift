//
//  Parser+Declaration.swift
//  Parser
//
//  Created by Hails, Daniel R on 03/09/2018.
//

import AST
import Lexer
import Foundation

extension Parser {
  // MARK: Modules
  func parseTopLevelModule() throws -> TopLevelModule {
    consumeNewLines()
    let topLevelDeclarations = try parseTopLevelDeclarations()
    let topLevelModule = TopLevelModule(declarations: topLevelDeclarations)

    return topLevelModule
  }

  // MARK: Top Level Declaration
  func parseTopLevelDeclarations() throws -> [TopLevelDeclaration] {
    var declarations = [TopLevelDeclaration]()

    while let first = currentToken {
      // At the top-level, a contract, a struct, a trait or a contract behavior can be declared.
      let second = tokens[currentIndex + 1].kind
      switch first.kind {
      case .contract:
        if second == .trait {
          let traitDeclaration = try parseTraitDeclaration()
          declarations.append(.traitDeclaration(traitDeclaration))
        } else {
          let contractDeclaration = try parseContractDeclaration()
          declarations.append(.contractDeclaration(contractDeclaration))
        }
      case .struct:
        if second == .trait {
          let traitDeclaration = try parseTraitDeclaration()
          declarations.append(.traitDeclaration(traitDeclaration))
        } else {
          let structDeclaration = try parseStructDeclaration()
          declarations.append(.structDeclaration(structDeclaration))
        }
      case .enum:
        let enumDeclaration = try parseEnumDeclaration()
        declarations.append(.enumDeclaration(enumDeclaration))
      case .identifier, .`self`:
        let contractBehaviorDeclaration = try parseContractBehaviorDeclaration()
        declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
      case .external, .punctuation(.at):
        let externalTraitDeclaration = try parseTraitDeclaration()
        declarations.append(.traitDeclaration(externalTraitDeclaration))
      default:
        diagnostics.append(.badTopLevelDeclaration(at: first.sourceLocation))
        // Skip to next non-empty line
        guard let eol = indexOfFirstAtCurrentDepth([.newline]) else {
          throw raise(.unexpectedEOF())
        }
        currentIndex = eol
        consumeNewLines()
      }
    }

    return declarations
  }

  func parseContractDeclaration() throws -> ContractDeclaration {
    let contractToken = try consume(.contract, or: .badTopLevelDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    var states: [TypeState] = []
    var conformances: [Conformance] = []
    if currentToken?.kind == .punctuation(.colon) {
      conformances = try parseConformances()
    }
    if currentToken?.kind == .punctuation(.openBracket) {
      states = try parseTypeStateGroup()
    } else {
      states = []
    }
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "contract declaration", at: latestSource))
    let members = try parseContractMembers(enclosingType: identifier.name)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "contract declaration", at: latestSource))

    return ContractDeclaration(contractToken: contractToken,
                               identifier: identifier,
                               conformances: conformances,
                               states: states,
                               members: members)
  }

  func parseStructDeclaration() throws -> StructDeclaration {
    let structToken = try consume(.struct, or: .badTopLevelDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    var conformances: [Conformance] = []
    if currentToken?.kind == .punctuation(.colon) {
      conformances = try parseConformances()
    }
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "struct declaration", at: latestSource))
    let members = try parseStructMembers(structIdentifier: identifier)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "struct declaration", at: latestSource))

    return StructDeclaration(structToken: structToken,
                             identifier: identifier,
                             conformances: conformances,
                             members: members)
  }

  func parseEnumDeclaration() throws -> EnumDeclaration {
    let enumToken = try consume(.enum, or: .badTopLevelDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "enum declaration", at: latestSource))
    let cases = try parseEnumCases(enumIdentifier: identifier, hiddenType: typeAnnotation.type)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "enum declaration", at: latestSource))

    return EnumDeclaration(enumToken: enumToken, identifier: identifier, type: typeAnnotation.type, cases: cases)
  }

  func parseTraitDeclaration() throws -> TraitDeclaration {
    let decorations: [FunctionCall] = attempt {
      return try parseDecorators()
    } ?? []

    let traitKind = try consume(anyOf: [.struct, .contract, .external], or: .badDeclaration(at: latestSource))
    let traitToken = try consume(.trait, or: .badDeclaration(at: latestSource))

    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "trait declaration", at: latestSource))
    let traitMembers = try parseTraitMembers()
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "trait declaration", at: latestSource))

    return TraitDeclaration(
        traitKind: traitKind,
        traitToken: traitToken,
        identifier: identifier,
        members: traitMembers,
        decorators: decorations
    )
  }

  func parseDecorators() throws -> [FunctionCall] {
    var decorators = [FunctionCall]()
    while currentToken?.kind == .punctuation(.at) {
      try consume(.punctuation(.at), or: .expectedValidOperator(at: latestSource))
      let decorator = try attempt {
        return try parseFunctionCall()
      } ?? FunctionCall(identifier: parseIdentifier(),
                        arguments: [],
                        closeBracketToken: Token.DUMMY,
                        isAttempted: false)
      decorators.append(decorator)
    }
    return decorators
  }

  func parseEventDeclaration() throws -> EventDeclaration {
    let eventToken = try consume(.event, or: .badDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    let (parameters, _) = try parseParameters()

    return EventDeclaration(eventToken: eventToken, identifier: identifier, parameters: parameters)
  }

  func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
    let contractIdentifier = try parseIdentifier()

    var states: [TypeState] = []
    var callerBinding: Identifier?

    if currentToken?.kind == .punctuation(.at) {
      _ = try consume(.punctuation(.at), or: .dummy())
      states = try parseTypeStateGroup()
    }

    try consume(.punctuation(.doubleColon), or: .expectedBehaviourSeparator(at: latestSource))

    if case .identifier(_)? = currentToken?.kind {
      callerBinding = try parseProtectionBinding()
    }
    let (callerProtections, closeBracketToken) = try parseCallerProtectionGroup()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "contract behavior", at: latestSource))

    let members = try parseContractBehaviorMembers(contractIdentifier: contractIdentifier.name)

    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "contract behavior", at: latestSource))

    return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier,
                                       states: states,
                                       callerBinding: callerBinding,
                                       callerProtections: callerProtections,
                                       closeBracketToken: closeBracketToken,
                                       members: members)
  }

  // MARK: Top Level Members
  func parseStructMembers(structIdentifier: Identifier) throws -> [StructMember] {
    var members = [StructMember]()
    while true {
      let attrs = try parseAttributes()
      let modifiers = try parseModifiers()

      let first = currentToken?.kind

      if first == .func {
        let decl = try parseFunctionDeclaration(attributes: attrs, modifiers: modifiers)
        members.append(.functionDeclaration(decl))
      } else if first == .`init` || first == .fallback {
        let decl = try parseSpecialDeclaration(attributes: attrs, modifiers: modifiers)
        members.append(.specialDeclaration(decl))
      } else if first == .invariant {
        _ = try consume(anyOf: [.invariant], or: .expectedInvariantDeclaration(at: latestSource))
        guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
          throw raise(.expectedInvariantDeclaration(at: latestSource))
        }
        members.append(.invariantDeclaration(try parseExpression(upTo: newLine)))
      } else if first == .var || first == .let,
                attrs.isEmpty {
        let decl = try parseVariableDeclaration(modifiers: modifiers,
                                                enclosingType: structIdentifier.name)
        members.append(.variableDeclaration(decl))
      } else if first == .punctuation(.closeBrace) {
        return members
      } else {
        throw raise(.badMember(in: "struct", at: latestSource))
      }
    }
  }

  func parseEnumCases(enumIdentifier: Identifier, hiddenType: Type) throws -> [EnumMember] {
    var cases = [EnumMember]()
    while let first = currentToken?.kind {
      if first == .case {
        cases.append(try parseEnumCase(enumIdentifier: enumIdentifier, hiddenType: hiddenType))
      } else if first == .punctuation(.closeBrace) {
        return cases
      } else {
        throw raise(.badMember(in: "enum", at: latestSource))
      }
    }
    return cases
  }

  func parseEnumCase(enumIdentifier: Identifier, hiddenType: Type) throws -> EnumMember {
    let caseToken = try consume(.case, or: .expectedEnumDeclarationCaseMember(at: latestSource))
    var identifier = try parseIdentifier()
    identifier.enclosingType = enumIdentifier.name
    var hiddenValue: Expression?
    if currentToken?.kind == .punctuation(.equal) {
      _ = try consume(.punctuation(.equal), or: .dummy())
      hiddenValue = try parseExpression(upTo: indexOfFirstAtCurrentDepth([.newline])!)
    }
    return EnumMember(caseToken: caseToken,
                      identifier: identifier,
                      type: Type(identifier: enumIdentifier),
                      hiddenValue: hiddenValue,
                      hiddenType: hiddenType)
  }

  func parseTraitMembers() throws -> [TraitMember] {
    var members = [TraitMember]()
    while let first = currentToken?.kind {
      switch first {
      case .punctuation(.closeBrace):
        return members
      default:
        members.append(try parseTraitMember())
      }
    }
    throw raise(.unexpectedEOF())
  }

  func parseTraitMember() throws -> TraitMember {
    guard let first = currentToken?.kind else {
      throw raise(.unexpectedEOF())
    }

    switch first {
    case .event:
      return .eventDeclaration(try parseEventDeclaration())
    case .self, .identifier:
      return .contractBehaviourDeclaration(try parseContractBehaviorDeclaration())
    default:
      break
    }

    let attrs = try parseAttributes()
    let modifiers = try parseModifiers()

    let declType = currentToken?.kind
    if .func == declType {
      // parse function signature, and if there's a body, parse that
      let signature = try parseFunctionSignatureDeclaration(attributes: attrs, modifiers: modifiers)
      consumeNewLines()

      if currentToken?.kind == .punctuation(.openBrace) {
        let (body, closeBraceToken) = try parseCodeBlock()
        return .functionDeclaration(
            FunctionDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken))
      }
      return .functionSignatureDeclaration(signature)
    } else if .`init` == declType {
      let signature = try parseSpecialSignatureDeclaration(attributes: attrs, modifiers: modifiers)
      consumeNewLines()

      if currentToken?.kind == .punctuation(.openBrace) {
        let (body, closeBraceToken) = try parseCodeBlock()
        return .specialDeclaration(
            SpecialDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken))
      }
      return .specialSignatureDeclaration(signature)
    } else {
      throw raise(.badMember(in: "trait", at: latestSource))
    }
  }

  func parseContractBehaviorMembers(contractIdentifier: RawTypeIdentifier) throws -> [ContractBehaviorMember] {
    var members = [ContractBehaviorMember]()

    while let first = currentToken?.kind {
      switch first {
      case .func, .`init`, .fallback, .public, .visible, .punctuation(.at):
        members.append(try parseContractBehaviorMember(enclosingType: contractIdentifier))
      case .punctuation(.closeBrace):
        return members
      default:
        throw raise(.badMember(in: "contract behaviour", at: latestSource))
      }
    }
    throw raise(.unexpectedEOF())
  }

  func parseContractBehaviorMember(enclosingType: RawTypeIdentifier) throws -> ContractBehaviorMember {

    let attrs = try parseAttributes()
    let modifiers = try parseModifiers()
    guard nil != indexOfFirstAtCurrentDepth([.newline]) else {
      throw raise(.statementSameLine(at: latestSource))
    }

    let declType = currentToken?.kind
    if .func == declType {
      // parse function signature, and if there's a body, parse that
      let signature = try parseFunctionSignatureDeclaration(attributes: attrs, modifiers: modifiers)
      consumeNewLines()

      if currentToken?.kind == .punctuation(.openBrace) {
        let (body, closeBraceToken) = try parseCodeBlock()
        return .functionDeclaration(
            FunctionDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken))
      }
      return .functionSignatureDeclaration(signature)
    } else if .`init` == declType || .fallback == declType {
      let signature = try parseSpecialSignatureDeclaration(attributes: attrs, modifiers: modifiers)
      consumeNewLines()

      if currentToken?.kind == .punctuation(.openBrace) {
        let (body, closeBraceToken) = try parseCodeBlock()
        return .specialDeclaration(
            SpecialDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken))
      }
      return .specialSignatureDeclaration(signature)
    }

    throw raise(.badMember(in: "contract behaviour", at: latestSource))
  }

  func parseContractMembers(enclosingType: RawTypeIdentifier) throws -> [ContractMember] {
    var members = [ContractMember]()

    while let first = currentToken?.kind {
      switch first {
      case .event, .public, .visible, .mutating, .var, .let, .invariant, .will:
        members.append(try parseContractMember(enclosingType: enclosingType))
      case .punctuation(.closeBrace):
        return members
      default:
        throw raise(.badMember(in: "contract", at: latestSource))
      }
    }
    throw raise(.unexpectedEOF())
  }

  func parseContractMember(enclosingType: RawTypeIdentifier) throws -> ContractMember {
    let first = currentToken?.kind

    if first == .event {
      return .eventDeclaration(try parseEventDeclaration())

    } else if first == .invariant {
      _ = try consume(anyOf: [.invariant], or: .expectedInvariantDeclaration(at: latestSource))
      guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
        throw raise(.expectedInvariantDeclaration(at: latestSource))
      }
      return .invariantDeclaration(try parseExpression(upTo: newLine))
    } else if first == .will {
      _ = try consume(anyOf: [.will], or: .expectedHolisticDeclaration(at: latestSource))
      guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
        throw raise(.expectedHolisticDeclaration(at: latestSource))
      }
      return .holisticDeclaration(try parseExpression(upTo: newLine))
    }

    let modifiers = try parseModifiers()

    let variableDeclaration = try parseVariableDeclaration(modifiers: modifiers,
                                                           enclosingType: enclosingType)
    return .variableDeclaration(variableDeclaration)
  }

  // MARK: Declarations
  func parseVariableDeclarations(enclosingType: RawTypeIdentifier) throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()
    while true {
      let modifiers = try parseModifiers()
      if currentToken?.kind == .var || currentToken?.kind == .let {

        let decl = try parseVariableDeclaration(modifiers: modifiers, enclosingType: enclosingType)
        variableDeclarations.append(decl)
      } else {
        break
      }
    }

    return variableDeclarations
  }

  /// Parses the declaration of a variable, as a state property (in a type) or a local variable.
  /// If a type property is assigned a default expression value, the expression will be stored in the
  /// `VariableDeclaration` struct, where an assignment to a local variable will be represented as a `BinaryExpression`
  /// with an `=` operator.
  ///
  /// - Parameter enclosingType: The name of the type in which the variable is declared, if it is a state property.
  /// - Returns: The parsed `VariableDeclaration`.
  /// - Throws: If the token streams cannot be parsed as a `VariableDeclaration`.
  func parseVariableDeclaration(modifiers: [Token],
                                enclosingType: RawTypeIdentifier? = nil, upTo: Int = -1) throws -> VariableDeclaration {

    var upTo = upTo

    if upTo == -1 {
      guard let newLine = getNewLineIndex() else {
        throw raise(.statementSameLine(at: latestSource))
      }

      upTo = newLine
    }

    let declarationToken = try consume(anyOf: [.var, .let], or: .badDeclaration(at: latestSource))

    var name = try parseIdentifier()
    if let enclosingType = enclosingType {
      name.enclosingType = enclosingType
    }

    let typeAnnotation = try parseTypeAnnotation()

    let assignedExpression: Expression?

    let asTypeProperty = enclosingType != nil

    if currentIndex >= upTo {
      assignedExpression = nil
    } else if currentToken?.kind == .punctuation(.equal) {
      // If we are parsing a state property defined in a type, and it has been assigned a default value,
      // parse it otherwise leave it to binary expression
      if asTypeProperty {
        _ = try consume(.punctuation(.equal), or: .expectedValidOperator(at: latestSource))
        assignedExpression = try parseExpression(upTo: upTo)
      } else {
        consumeNewLines()
        assignedExpression = nil
      }
    } else {
      throw raise(.expectedValidOperator(at: latestSource))
    }

    return VariableDeclaration(modifiers: modifiers,
                               declarationToken: declarationToken,
                               identifier: name,
                               type: typeAnnotation.type,
                               assignedExpression: assignedExpression)
  }

  func getNewLineIndex() -> Int? {

    let upperBound = tokens.count
    guard currentIndex <= upperBound else { return nil }

    let range = (currentIndex..<upperBound)
    for index in range {
      let currentTok = tokens[index].kind
      if currentTok == .newline {
        return index
      }
    }

    return nil
  }

  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow), or: .expectedRightArrow(at: latestSource))
    let identifier = try parseIdentifier()
    return Type(identifier: identifier)
  }

  func parsePrePostConditions() throws -> [PrePostCondition] {
    var conditions = [PrePostCondition]()

    OUTER:
    while let condType = currentToken?.kind {
      switch condType {
      case .pre:
        conditions.append(.pre(try parsePrePostCondition()))
      case .post:
        conditions.append(.post(try parsePrePostCondition()))
      default:
        break OUTER
      }
    }
    return conditions
  }

  func parsePrePostCondition() throws -> Expression {
    _ = try consume(anyOf: [.pre, .post], or: .badPrePostConditionDeclaration(at: latestSource))
    guard let index = indexOfFirstAtCurrentDepth([.newline]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }
    let expression = try parseExpression(upTo: index)
    return expression
  }

  func parseFunctionDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> FunctionDeclaration {
    let signature = try parseFunctionSignatureDeclaration(attributes: attributes, modifiers: modifiers)
    let (body, closeBraceToken) = try parseCodeBlock()

    return FunctionDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken)
  }

  func parseFunctionSignatureDeclaration(attributes: [Attribute],
                                         modifiers: [Token]) throws -> FunctionSignatureDeclaration {
    let funcToken = try consume(.func, or: .badDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    let (parameters, closeBracketToken) = try parseParameters()
    let resultType: Type?
    if currentToken?.kind == .punctuation(.arrow) {
      resultType = try parseResult()
    } else {
      resultType = nil
    }
    let mutates = try parseMutates()
    let prePostConditions = try parsePrePostConditions()

    return FunctionSignatureDeclaration(
        funcToken: funcToken,
        attributes: attributes,
        modifiers: modifiers,
        mutates: mutates,
        identifier: identifier,
        parameters: parameters,
        prePostConditions: prePostConditions,
        closeBracketToken: closeBracketToken,
        resultType: resultType
    )
  }

  func parseSpecialDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> SpecialDeclaration {
    let signature = try parseSpecialSignatureDeclaration(attributes: attributes, modifiers: modifiers)
    let (body, closeBraceToken) = try parseCodeBlock()
    return SpecialDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken)
  }

  func parseSpecialSignatureDeclaration(attributes: [Attribute],
                                        modifiers: [Token]) throws -> SpecialSignatureDeclaration {
    let specialToken: Token = try consume(anyOf: [.`init`, .fallback], or: .badDeclaration(at: latestSource))
    let (parameters, closeBracketToken) = try parseParameters()
    let mutates = try parseMutates()
    let prePostConditions = try parsePrePostConditions()

    return SpecialSignatureDeclaration(
        specialToken: specialToken,
        attributes: attributes,
        modifiers: modifiers,
        mutates: mutates,
        parameters: parameters,
        prePostConditions: prePostConditions,
        closeBracketToken: closeBracketToken
    )
  }
}
