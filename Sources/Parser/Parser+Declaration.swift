//
//  Parser+Declaration.swift
//  Parser
//
//  Created by Hails, Daniel R on 03/09/2018.
//
import AST
import Lexer

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
      // At the top-level, a contract, a struct, or a contract behavior can be declared.
      switch first.kind {
      case .contract:
        let contractDeclaration = try parseContractDeclaration()
        declarations.append(.contractDeclaration(contractDeclaration))
      case .struct:
        let structDeclaration = try parseStructDeclaration()
        declarations.append(.structDeclaration(structDeclaration))
      case .enum:
        let enumDeclaration = try parseEnumDeclaration()
        declarations.append(.enumDeclaration(enumDeclaration))
      case .trait:
        let traitDeclaration = try parseTraitDeclaration()
        declarations.append(.traitDeclaration(traitDeclaration))
      case .identifier(_):
        let contractBehaviorDeclaration = try parseContractBehaviorDeclaration()
        declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
      default:
        diagnostics.append(.badTopLevelDeclaration(at: first.sourceLocation))
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

    return ContractDeclaration(contractToken: contractToken, identifier: identifier, conformances: conformances, states: states, members: members)
  }

  func parseStructDeclaration() throws -> StructDeclaration {
    let structToken = try consume(.struct, or: .badTopLevelDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "struct declaration", at: latestSource))
    let members = try parseStructMembers(structIdentifier: identifier)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "struct declaration", at: latestSource))

    return StructDeclaration(structToken: structToken, identifier: identifier, members: members)
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
    let traitToken = try consume(.trait, or: .badDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "trait declaration", at: latestSource))
    let traitMembers = try parseTraitMembers()
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "trait declaration", at: latestSource))

    return TraitDeclaration(
      traitToken: traitToken,
      identifier: identifier,
      members: traitMembers
    )
  }

  func parseEventDeclaration() throws -> EventDeclaration {
    let eventToken = try consume(.event, or: .badDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "event declaration", at: latestSource))
    let variables = try parseVariableDeclarations(enclosingType: identifier.name)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "event declaration", at: latestSource))

    return EventDeclaration(eventToken: eventToken, identifier: identifier, variables: variables)
  }

  func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
    let contractIdentifier = try parseIdentifier()

    var states: [TypeState] = []
    var capabilityBinding: Identifier? = nil

    if currentToken?.kind == .punctuation(.at) {
      let _ = try consume(.punctuation(.at), or: .dummy())
      states = try parseTypeStateGroup()
    }

    try consume(.punctuation(.doubleColon), or: .expectedBehaviourSeparator(at: latestSource))

    if case .identifier(_)? = currentToken?.kind {
      capabilityBinding = try parseCapabilityBinding()
    }
    let (callerCapabilities, closeBracketToken) = try parseCallerCapabilityGroup()
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "contract behavior", at: latestSource))

    let members = try parseContractBehaviorMembers(contractIdentifier: contractIdentifier.name)

    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "contract behavior", at: latestSource))

    return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, states: states, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, closeBracketToken: closeBracketToken, members: members)
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
      } else if first == .init || first == .fallback {
        let decl = try parseSpecialDeclaration(attributes: attrs, modifiers: modifiers)
        members.append(.specialDeclaration(decl))
      } else if first == .var || first == .let,
        attrs.isEmpty {
        guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
          throw raise(.statementSameLine(at: latestSource))
        }
        let decl = try parseVariableDeclaration(modifiers: modifiers, enclosingType: structIdentifier.name, upTo: newLine)
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
    var hiddenValue: Expression? = nil
    if currentToken?.kind == .punctuation(.equal) {
      let _ = try consume(.punctuation(.equal), or: .dummy())
      hiddenValue = try parseExpression(upTo: indexOfFirstAtCurrentDepth([.newline])!)
    }
    return EnumMember(caseToken: caseToken, identifier: identifier, type: Type(identifier: enumIdentifier), hiddenValue: hiddenValue, hiddenType: hiddenType)
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
    let first = currentToken?.kind

    if first == .event {
      return .eventDeclaration(try parseEventDeclaration())
    }

    let attrs = try parseAttributes()
    let modifiers = try parseModifiers()
    guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
      throw raise(.statementSameLine(at: latestSource))
    }
    let signatureDeclaration: Bool
    if let openBrace = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]), openBrace < newLine {
      signatureDeclaration = false
    } else {
      signatureDeclaration = true
    }

    let declType = currentToken?.kind
    if .func == declType {
      if signatureDeclaration {
        return .functionSignatureDeclaration(try parseFunctionSignatureDeclaration(attributes: attrs, modifiers: modifiers))
      } else {
        return .functionDeclaration(try parseFunctionDeclaration(attributes: attrs, modifiers: modifiers))
      }
    } else if .init == declType {
      if signatureDeclaration {
        return .specialSignatureDeclaration(try parseSpecialSignatureDeclaration(attributes: attrs, modifiers: modifiers))
      } else {
        return .specialDeclaration(try parseSpecialDeclaration(attributes: attrs, modifiers: modifiers))
      }
    } else {
      throw raise(.badMember(in: "trait", at: latestSource))
    }
  }

  func parseContractBehaviorMembers(contractIdentifier: RawTypeIdentifier) throws -> [ContractBehaviorMember] {
    var members = [ContractBehaviorMember]()

    while true {
      let attrs = try parseAttributes()
      let modifiers = try parseModifiers()

      let first = currentToken?.kind

      if first == .func {
        let decl = try parseFunctionDeclaration(attributes: attrs, modifiers: modifiers)
        members.append(.functionDeclaration(decl))
      } else if first == .init || first == .fallback {
        let decl = try parseSpecialDeclaration(attributes: attrs, modifiers: modifiers)
        members.append(.specialDeclaration(decl))
      } else if first == .punctuation(.closeBrace) {
        return members
      } else {
        throw raise(.badMember(in: "contract behaviour", at: latestSource))
      }
    }
  }

  func parseContractMembers(enclosingType: RawTypeIdentifier) throws -> [ContractMember] {
    var members = [ContractMember]()

    while let first = currentToken?.kind {
      switch first {
      case .event, .public, .visible, .mutating, .var, .let:
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
    }

    let modifiers = try parseModifiers()
    guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
      throw raise(.statementSameLine(at: latestSource))
    }
    let variableDeclaration = try parseVariableDeclaration(modifiers: modifiers, enclosingType: enclosingType, upTo: newLine)
    return .variableDeclaration(variableDeclaration)

  }

  // MARK: Declarations
  func parseVariableDeclarations(enclosingType: RawTypeIdentifier) throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()
    while true {
      let modifiers = try parseModifiers()
      if currentToken?.kind == .var || currentToken?.kind == .let {
        guard let newLine = indexOfFirstAtCurrentDepth([.newline]) else {
          throw raise(.statementSameLine(at: latestSource))
        }
        let decl = try parseVariableDeclaration(modifiers: modifiers, enclosingType: enclosingType, upTo: newLine)
        variableDeclarations.append(decl)
      }
      else {
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
  func parseVariableDeclaration(modifiers: [Token], enclosingType: RawTypeIdentifier? = nil, upTo: Int) throws -> VariableDeclaration {

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
      // If we are parsing a state property defined in a type, and it has been assigned a default value, parse it otherwise leave it to binary expression
      if asTypeProperty {
        let _ = try consume(.punctuation(.equal), or: .expectedValidOperator(at: latestSource))
        assignedExpression = try parseExpression(upTo: upTo)
      } else {
        assignedExpression = nil
      }
    } else {
      throw raise(.expectedValidOperator(at: latestSource))
    }

    return VariableDeclaration(modifiers: modifiers, declarationToken: declarationToken, identifier: name, type: typeAnnotation.type, assignedExpression: assignedExpression)
  }

  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow), or: .expectedRightArrow(at: latestSource))
    let identifier = try parseIdentifier()
    return Type(identifier: identifier)
  }

  func parseFunctionDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> FunctionDeclaration {
    let signature = try parseFunctionSignatureDeclaration(attributes: attributes, modifiers: modifiers)
    let (body, closeBraceToken) = try parseCodeBlock()

    return FunctionDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken)
  }

  func parseFunctionSignatureDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> FunctionSignatureDeclaration {
    let funcToken = try consume(.func, or: .badDeclaration(at: latestSource))
    let identifier = try parseIdentifier()
    let (parameters, closeBracketToken) = try parseParameters()
    let resultType: Type?
    if currentToken?.kind == .punctuation(.arrow) {
      resultType = try parseResult()
    } else {
      resultType = nil
    }

    return FunctionSignatureDeclaration(
      funcToken: funcToken,
      attributes: attributes,
      modifiers: modifiers,
      identifier: identifier,
      parameters: parameters,
      closeBracketToken: closeBracketToken,
      resultType: resultType
    )
  }

  func parseSpecialDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> SpecialDeclaration {
    let signature = try parseSpecialSignatureDeclaration(attributes: attributes, modifiers: modifiers)
    let (body, closeBraceToken) = try parseCodeBlock()
    return SpecialDeclaration(signature: signature, body: body, closeBraceToken: closeBraceToken)
  }

  func parseSpecialSignatureDeclaration(attributes: [Attribute], modifiers: [Token]) throws -> SpecialSignatureDeclaration {
    let specialToken: Token = try consume(anyOf: [.init, .fallback], or: .badDeclaration(at: latestSource))
    let (parameters, closeBracketToken) = try parseParameters()

    return SpecialSignatureDeclaration(
      specialToken: specialToken,
      attributes: attributes,
      modifiers: modifiers,
      parameters: parameters,
      closeBracketToken: closeBracketToken
    )
  }
}
