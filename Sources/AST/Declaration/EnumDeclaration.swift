//
//  EnumDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
public struct EnumCase: SourceEntity {
  public var caseToken: Token
  public var identifier: Identifier
  public var type: Type

  public var hiddenValue: Expression?
  public var hiddenType: Type

  public var sourceLocation: SourceLocation {
    return caseToken.sourceLocation
  }

  public init(caseToken: Token, identifier: Identifier, type: Type, hiddenValue: Expression?, hiddenType: Type){
    self.caseToken = caseToken
    self.identifier = identifier
    self.hiddenValue = hiddenValue
    self.type = type
    self.hiddenType = hiddenType
  }
}

public struct EnumDeclaration: SourceEntity {
  public var enumToken: Token
  public var identifier: Identifier
  public var type: Type
  public var cases: [EnumCase]

  public var sourceLocation: SourceLocation {
    return enumToken.sourceLocation
  }

  public init(enumToken: Token, identifier: Identifier, type: Type, cases: [EnumCase]) {
    self.enumToken = enumToken
    self.identifier = identifier
    self.cases = cases
    self.type = type

    synthesizeRawValues()
  }

  mutating func synthesizeRawValues(){
    let dummySourceLocation = sourceLocation
    var lastRawValue: Expression?
    var newCases = [EnumCase]()

    for var enumCase in cases {
      if enumCase.hiddenValue == nil, type.rawType == .basicType(.int) {
        if lastRawValue == nil {
          enumCase.hiddenValue = .literal(.init(kind: .literal(.decimal(.integer(0))), sourceLocation: dummySourceLocation))
        }
        else if case .literal(let token)? = lastRawValue,
          case .literal(.decimal(.integer(let i))) = token.kind {
          enumCase.hiddenValue = .literal(.init(kind: .literal(.decimal(.integer(i + 1))), sourceLocation: dummySourceLocation))
        }

      }

      if enumCase.hiddenValue != nil {
        lastRawValue = enumCase.hiddenValue
      }
      newCases.append(enumCase)
    }
    cases = newCases
  }
}
