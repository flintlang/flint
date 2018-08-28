//
//  StructDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A member in a struct declaration.
///
/// - variableDeclaration: The declaration of a variable.
/// - functionDeclaration: The declaration of a function.
public enum StructMember: ASTNode {
  case variableDeclaration(VariableDeclaration)
  case functionDeclaration(FunctionDeclaration)
  case specialDeclaration(SpecialDeclaration)

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
      case .variableDeclaration(let variableDeclaration):
        return variableDeclaration.sourceLocation
      case .functionDeclaration(let functionDeclaration):
        return functionDeclaration.sourceLocation
      case .specialDeclaration(let specialDeclaration):
        return specialDeclaration.sourceLocation
    }
  }

  public var description: String {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.description
    case .functionDeclaration(let functionDeclaration):
      return functionDeclaration.description
    case .specialDeclaration(let specialDeclaration):
      return specialDeclaration.description
    }
  }
}

/// The declaration of a struct.
public struct StructDeclaration: ASTNode {
  public var structToken: Token
  public var identifier: Identifier
  public var members: [StructMember]

  public var variableDeclarations: [VariableDeclaration] {
    return members.compactMap { member in
      guard case .variableDeclaration(let variableDeclaration) = member else { return nil }
      return variableDeclaration
    }
  }

  public var functionDeclarations: [FunctionDeclaration] {
    return members.compactMap { member in
      guard case .functionDeclaration(let functionDeclaration) = member else { return nil }
      return functionDeclaration
    }
  }

  public var specialDeclarations: [SpecialDeclaration] {
      return members.compactMap { member in
        guard case .specialDeclaration(let specialDeclaration) = member else { return nil }
        return specialDeclaration
      }
    }

  private var shouldInitializerBeSynthesized: Bool {
    // Don't synthesize an initializer for the special stdlib Flint$Global struct.
    guard identifier.name != Environment.globalFunctionStructName else {
      return false
    }

    let containsInitializer = members.contains { member in
      if case .specialDeclaration(let specialDeclaration) = member, specialDeclaration.isInit { return true }
      return false
    }

    guard !containsInitializer else { return false }

    let unassignedProperties = members.compactMap { member -> VariableDeclaration? in
      guard case .variableDeclaration(let variableDeclaration) = member,
        variableDeclaration.assignedExpression == nil else {
          return nil
      }
      return variableDeclaration
    }

    return unassignedProperties.count == 0
  }

  public init(structToken: Token, identifier: Identifier, members: [StructMember]) {
    self.structToken = structToken
    self.identifier = identifier
    self.members = members

    // Synthesize an initializer if none was defined.
    if shouldInitializerBeSynthesized {
      self.members.append(.specialDeclaration(synthesizeInitializer()))
    }
  }

  mutating func synthesizeInitializer() -> SpecialDeclaration {
    // Synthesize the initializer.
    let dummySourceLocation = sourceLocation
    let closeBraceToken = Token(kind: .punctuation(.closeBrace), sourceLocation: dummySourceLocation)
    let closeBracketToken = Token(kind: .punctuation(.closeBracket), sourceLocation: dummySourceLocation)
    return SpecialDeclaration(specialToken: Token(kind: .init, sourceLocation: dummySourceLocation), attributes: [], modifiers: [], parameters: [], closeBracketToken: closeBracketToken, body: [], closeBraceToken: closeBraceToken, scopeContext: ScopeContext())
  }

  // MARK: - ASTNode
  public var description: String {
    let memberText = members.map({ $0.description }).joined(separator: "\n")
    return "\(structToken) \(identifier) {\(memberText)}"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(structToken, to: identifier)
  }
}
