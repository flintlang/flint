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
    let states = attempt(try parseTypeStateGroup())
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "contract declaration", at: latestSource))
    let members = try parserContractMembers(enclosingType: identifier.name)
    try consume(.punctuation(.closeBrace), or: .rightBraceExpected(in: "contract declaration", at: latestSource))

    return ContractDeclaration(contractToken: contractToken, identifier: identifier, states: states ?? [], members: members)
  }

  func parserContractMembers(enclosingType: RawTypeIdentifier) throws -> [ContractMember] {
    var members = [ContractMember]()

    while let member = attempt(try parseContractMember(enclosingType: enclosingType)) {
      members.append(member)
    }

    return members
  }

  func parseContractMember(enclosingType: RawTypeIdentifier) throws -> ContractMember {
    if let variableDeclaration = attempt(try parseVariableDeclaration(enclosingType: enclosingType)){
      return .variableDeclaration(variableDeclaration)
    }
    return .eventDeclaration(try parseEventDeclaration())
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
    if currentToken?.kind == .punctuation(.at) {
      let _ = attempt(try consume(.punctuation(.at), or: .dummy()))
      states = try parseTypeStateGroup()
    }


    try consume(.punctuation(.doubleColon), or: .expectedBehaviourSeparator(at: latestSource))

    let capabilityBinding = attempt(parseCapabilityBinding)
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
      if let variableDeclaration = attempt(try parseVariableDeclaration(enclosingType: structIdentifier.name)) {
        members.append(.variableDeclaration(variableDeclaration))
      } else if let functionDeclaration = attempt(parseFunctionDeclaration) {
        members.append(.functionDeclaration(functionDeclaration))
      } else if let specialDeclaration = attempt(parseSpecialDeclaration) {
        members.append(.specialDeclaration(specialDeclaration))
      } else {
        break
      }
    }

    return members
  }
  
  func parseEnumCases(enumIdentifier: Identifier, hiddenType: Type) throws -> [EnumMember] {
    var cases = [EnumMember]()
    while let enumCase = attempt(try parseEnumCase(enumIdentifier: enumIdentifier, hiddenType: hiddenType)) {
      cases.append(enumCase)
    }

    return cases
  }

  func parseEnumCase(enumIdentifier: Identifier, hiddenType: Type) throws -> EnumMember {
    let caseToken = try consume(.case, or: .expectedEnumDeclarationCaseMember(at: latestSource))
    var identifier = try parseIdentifier()
    identifier.enclosingType = enumIdentifier.name
    var hiddenValue: Expression? = nil
    if attempt(try consume(.punctuation(.equal), or: .dummy())) != nil {
      hiddenValue = try parseExpression(upTo: indexOfFirstAtCurrentDepth([.newline])!)
    }
    return EnumMember(caseToken: caseToken, identifier: identifier, type: Type(identifier: enumIdentifier), hiddenValue: hiddenValue, hiddenType: hiddenType)
  }
  
  func parseContractBehaviorMembers(contractIdentifier: RawTypeIdentifier) throws -> [ContractBehaviorMember] {
    var members = [ContractBehaviorMember]()

    while true {
      if let functionDeclaration = attempt(parseFunctionDeclaration) {
        members.append(.functionDeclaration(functionDeclaration))
      } else if let specialDeclaration = attempt(parseSpecialDeclaration) {
        members.append(.specialDeclaration(specialDeclaration))
      } else {
        break
      }
    }

    return members
  }


  // MARK: Declarations
  func parseVariableDeclarations(enclosingType: RawTypeIdentifier) throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()

    while let variableDeclaration = attempt(try parseVariableDeclaration(enclosingType: enclosingType)) {
      variableDeclarations.append(variableDeclaration)
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
  func parseVariableDeclaration(enclosingType: RawTypeIdentifier? = nil) throws -> VariableDeclaration {

    let modifiers = attempt(try parseModifiers())

    let declarationToken = try consume(anyOf: [.var, .let], or: .badDeclaration(at: latestSource))


    var name = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()

    let assignedExpression: Expression?

    let asTypeProperty = enclosingType != nil

    // If we are parsing a state property defined in a type, and it has been assigned a default value, parse it.
    if asTypeProperty, let _ = attempt(try consume(.punctuation(.equal), or: .expectedValidOperator(at: latestSource))) {
      guard let newLineIndex = indexOfFirstAtCurrentDepth([.newline]) else {
        throw raise(.statementSameLine(at: latestSource))
      }
      assignedExpression = try parseExpression(upTo: newLineIndex)
    } else {
      assignedExpression = nil
    }

    if let enclosingType = enclosingType {
      name.enclosingType = enclosingType
    }

    return VariableDeclaration(modifiers: modifiers ?? [], declarationToken: declarationToken, identifier: name, type: typeAnnotation.type, assignedExpression: assignedExpression)
  }
  
  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow), or: .expectedRightArrow(at: latestSource))
    let identifier = try parseIdentifier()
    return Type(identifier: identifier)
  }

  func parseFunctionHead() throws -> (attributes: [Attribute], modifiers: [Token], funcToken: Token) {
    let attributes = try parseAttributes()
    let modifiers = try parseModifiers()

    let funcToken = try consume(.func, or: .badDeclaration(at: latestSource))
    return (attributes, modifiers, funcToken)
  }


  func parseFunctionDeclaration() throws -> FunctionDeclaration {
    let (attributes, modifiers, funcToken) = try parseFunctionHead()
    let identifier = try parseIdentifier()
    let (parameters, closeBracketToken) = try parseParameters()
    let resultType = attempt(parseResult)
    let (body, closeBraceToken) = try parseCodeBlock()

    return FunctionDeclaration(funcToken: funcToken, attributes: attributes, modifiers: modifiers, identifier: identifier, parameters: parameters, closeBracketToken: closeBracketToken, resultType: resultType, body: body, closeBraceToken: closeBraceToken)
  }

  func parseSpecialHead() throws -> (attributes: [Attribute], modifiers: [Token], initToken: Token) {
    let attributes = try parseAttributes()
    let modifiers = try parseModifiers()

    let specialToken: Token = try consume(anyOf: [.init, .fallback], or: .badDeclaration(at: latestSource))
    return (attributes, modifiers, specialToken)
  }

  func parseSpecialDeclaration() throws -> SpecialDeclaration {
    let (attributes, modifiers, specialToken) = try parseSpecialHead()
    let (parameters, closeBracketToken) = try parseParameters()
    let (body, closeBraceToken) = try parseCodeBlock()
    return SpecialDeclaration(specialToken: specialToken, attributes: attributes, modifiers: modifiers, parameters: parameters, closeBracketToken: closeBracketToken, body: body, closeBraceToken: closeBraceToken)
  }
}
