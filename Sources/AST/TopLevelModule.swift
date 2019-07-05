//
//  TopLevelModule.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A Flint top-level module. Includes top-level declarations, such as contract, struct, and contract behavior
/// declarations.
public struct TopLevelModule: ASTNode {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
    let contracts = declarations.compactMap { (tld) -> ContractDeclaration? in
      if case TopLevelDeclaration.contractDeclaration(let contract) = tld {
        return contract
      }
      return nil
    }
    let synthesizedBehaviours: [TopLevelDeclaration] = contracts.map {
      .contractBehaviorDeclaration(accessorsAndMutators(contract: $0))
    }
    self.declarations.append(contentsOf: synthesizedBehaviours)
  }

  func accessorsAndMutators(contract: ContractDeclaration) -> ContractBehaviorDeclaration {
    let mutatorVariables = contract.variableDeclarations.filter({ $0.isPublic })
    let visibleVariables = contract.variableDeclarations.filter({ $0.isVisible })
    let accessorVariables = mutatorVariables + visibleVariables

    let accessors: [ContractBehaviorMember] = accessorVariables.compactMap { synthesizeAccessor(variable: $0)}
                                                               .map { .functionDeclaration($0) }
    let mutators: [ContractBehaviorMember] = mutatorVariables.compactMap { synthesizeMutator(variable: $0)}
      .map { .functionDeclaration($0) }

    let dummyCloseToken = Token(kind: .punctuation(.closeBrace), sourceLocation: contract.sourceLocation)
    let anyIdentifier = Identifier(identifierToken: Token(kind: .identifier("any"),
                                                          sourceLocation: contract.sourceLocation))
    let states = contract.isStateful ? [TypeState(identifier: anyIdentifier)] : []

    return ContractBehaviorDeclaration(contractIdentifier: contract.identifier,
                                       states: states,
                                       callerBinding: nil,
                                       callerProtections: [CallerProtection(identifier: anyIdentifier)],
                                       closeBracketToken: dummyCloseToken,
                                       members: accessors + mutators)

  }

  func synthesizeAccessor(variable: VariableDeclaration) -> FunctionDeclaration? {
    let dummyFuncToken = Token(kind: .func, sourceLocation: variable.sourceLocation)
    let dummyCloseToken = Token(kind: .punctuation(.closeBrace), sourceLocation: variable.sourceLocation)

    let capitalisedFirst = variable.identifier.name.prefix(1).uppercased() + variable.identifier.name.dropFirst()

    let identifier = Identifier(identifierToken: Token(kind: .identifier("get"+capitalisedFirst),
                                                       sourceLocation: variable.identifier.sourceLocation))
    guard let (parameters, expression, resultType) = getProperty(identifier: variable.identifier,
                                                                 variableType: variable.type,
                                                                 sourceLocation: variable.sourceLocation) else {
      return nil
    }
    let body = [
      Statement.returnStatement(
        ReturnStatement(returnToken: Token(kind: .return, sourceLocation: variable.sourceLocation),
                        expression: expression)
      )
    ]

    let functionSignature = FunctionSignatureDeclaration(funcToken: dummyFuncToken,
                                                         attributes: [],
                                                         modifiers: [
                                                          Token(kind: .public, sourceLocation: variable.sourceLocation)
                                                         ],
                                                         mutates: [],
                                                         identifier: identifier,
                                                         parameters: parameters,
                                                         prePostConditions: [],
                                                         closeBracketToken: dummyCloseToken,
                                                         resultType: resultType)

    return FunctionDeclaration(signature: functionSignature, body: body, closeBraceToken: dummyCloseToken)
  }

  func synthesizeMutator(variable: VariableDeclaration) -> FunctionDeclaration? {
    let dummyFuncToken = Token(kind: .func, sourceLocation: variable.sourceLocation)
    let dummyCloseToken = Token(kind: .punctuation(.closeBrace), sourceLocation: variable.sourceLocation)

    let capitalisedFirst = variable.identifier.name.prefix(1).uppercased() + variable.identifier.name.dropFirst()

    let identifier = Identifier(identifierToken: Token(kind: .identifier("set"+capitalisedFirst),
                                                       sourceLocation: variable.identifier.sourceLocation))
    guard let (parameters, expression, resultType) = getProperty(identifier: variable.identifier,
                                                                 variableType: variable.type,
                                                                 sourceLocation: variable.sourceLocation) else {
      return nil
    }
    let valueIdentifier = Identifier(identifierToken: Token(kind: .identifier("value"),
                                                            sourceLocation: variable.sourceLocation))
    let valueParameter = Parameter(identifier: valueIdentifier,
                                   type: resultType,
                                   implicitToken: nil,
                                   assignedExpression: nil)
    let body = [
      Statement.expression(.binaryExpression(
        BinaryExpression(lhs: expression,
                         op: Token(kind: .punctuation(.equal), sourceLocation: variable.sourceLocation),
                         rhs: .identifier(valueIdentifier))))
    ]

    let functionSignature = FunctionSignatureDeclaration(funcToken: dummyFuncToken,
                                                          attributes: [],
                                                          modifiers: [
                                                            Token(kind: .public,
                                                                  sourceLocation: variable.sourceLocation)
                                                          ],
                                                          mutates: [],
                                                          identifier: identifier,
                                                          parameters: parameters + [valueParameter],
                                                          prePostConditions: [],
                                                          closeBracketToken: dummyCloseToken,
                                                          resultType: nil)

    return FunctionDeclaration(signature: functionSignature, body: body, closeBraceToken: dummyCloseToken)
  }

  func getProperty(identifier: Identifier, variableType: Type,
                   sourceLocation: SourceLocation) -> ([Parameter], Expression, Type)? {
    switch variableType.rawType {
    case .basicType:
      return ([], .identifier(identifier), variableType)
    case .arrayType(let type), .fixedSizeArrayType(let type, _):
      var identifiers = [Identifier]()
      var currentType: RawType = type
      let avaliableIdentifiers = "ijklmnopqrstuvwxyzabcdefgh"
      var index = avaliableIdentifiers.startIndex

      while index != avaliableIdentifiers.endIndex {
        index = avaliableIdentifiers.index(index, offsetBy: 1)
        let name = avaliableIdentifiers[index].description
        identifiers.append(Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation)))

        if case .arrayType(let type) = currentType {
          currentType = type
          continue
        }
        if case .fixedSizeArrayType(let type, _) = currentType {
          currentType = type
          continue
        }
        break
      }

      let parameters = identifiers.map {
        Parameter(identifier: $0,
                  type: Type(inferredType: .basicType(.int), identifier: $0),
                  implicitToken: nil,
                  assignedExpression: nil)
      }

      let subscriptExpression =
        identifiers.reduce(.identifier(identifier), { (currentExpression, identifier) -> Expression in
        return .subscriptExpression(
          SubscriptExpression(baseExpression: currentExpression,
                              indexExpression: .identifier(identifier),
                              closeSquareBracketToken: Token(kind: .punctuation(.closeSquareBracket),
                                                             sourceLocation: sourceLocation)))
      })

      return (parameters, subscriptExpression, Type(inferredType: currentType, identifier: identifier))
    case .dictionaryType(let key, let value):
      let keyIdentifier = Identifier(identifierToken: Token(kind: .identifier("key"), sourceLocation: sourceLocation))
      let keyParameter = Parameter(identifier: keyIdentifier,
                                   type: Type(inferredType: key,
                                              identifier: identifier),
                                   implicitToken: nil,
                                   assignedExpression: nil)
      let subExpression = SubscriptExpression(baseExpression: .identifier(identifier),
                                              indexExpression: .identifier(keyIdentifier),
                                              closeSquareBracketToken: Token(kind: .punctuation(.closeSquareBracket),
                                                                             sourceLocation: sourceLocation))
      return ([keyParameter], .subscriptExpression(subExpression), Type(inferredType: value, identifier: identifier))
    case .rangeType, .userDefinedType, .inoutType, .functionType, .selfType, .any, .errorType, .solidityType:
      return nil
    }
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    guard let firstTLD = declarations.first,
      let lastTLD = declarations.last else {
        return .INVALID
    }
    return .spanning(firstTLD, to: lastTLD)
  }

  public var description: String {
    return declarations.map({ $0.description }).joined(separator: "\n")
  }
}
