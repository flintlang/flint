//
//  EnumDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
public struct EnumCase: ASTNode {
  public var caseToken: Token
  public var identifier: Identifier
  public var type: Type

  public var hiddenValue: Expression?
  public var hiddenType: Type

  public init(caseToken: Token, identifier: Identifier, type: Type, hiddenValue: Expression?, hiddenType: Type){
    self.caseToken = caseToken
    self.identifier = identifier
    self.hiddenValue = hiddenValue
    self.type = type
    self.hiddenType = hiddenType
  }

  // MARK: - ASTNode
  public var description: String {
    return "case \(identifier)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(caseToken, to: identifier)
  }
}

public struct EnumDeclaration: ASTNode {
  public var enumToken: Token
  public var identifier: Identifier
  public var type: Type
  public var cases: [EnumCase]

  public init(enumToken: Token, identifier: Identifier, type: Type, cases: [EnumCase]) {
    self.enumToken = enumToken
    self.identifier = identifier
    self.cases = cases
    self.type = type

    synthesizeRawValues()
  }

  mutating func synthesizeRawValues(){
    var lastRawValue: Expression?
    var newCases = [EnumCase]()

    for var enumCase in cases {
      if enumCase.hiddenValue == nil, type.rawType == .basicType(.int) {
        if lastRawValue == nil {
          enumCase.hiddenValue = .literal(.init(kind: .literal(.decimal(.integer(0))), sourceLocation: .DUMMY))
        }
        else if case .literal(let token)? = lastRawValue,
          case .literal(.decimal(.integer(let i))) = token.kind {
          enumCase.hiddenValue = .literal(.init(kind: .literal(.decimal(.integer(i + 1))), sourceLocation: .DUMMY))
        }

      }

      if enumCase.hiddenValue != nil {
        lastRawValue = enumCase.hiddenValue
      }
      newCases.append(enumCase)
    }
    cases = newCases
  }

  // MARK: - ASTNode
  public var description: String {
    let headText = "enum \(identifier): \(type)"
    let variablesText = cases.map({ $0.description }).joined(separator: "\n")
    return "\(headText) {\(variablesText)}"
  }
  public var sourceLocation: SourceLocation {
    if cases.isEmpty {
      return .spanning(enumToken, to: type)
    }
    return .spanning(enumToken, to: cases.last!)
  }
}
