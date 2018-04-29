//
//  IULIAExpression.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST

/// Generates code for an expression.
struct IULIAExpression {
  var expression: Expression
  var asLValue: Bool

  init(expression: Expression, asLValue: Bool = false) {
    self.expression = expression
    self.asLValue = asLValue
  }
  
  func rendered(functionContext: FunctionContext) -> String {
    switch expression {
    case .inoutExpression(let inoutExpression):
      return IULIAExpression(expression: inoutExpression.expression, asLValue: true).rendered(functionContext: functionContext)
    case .binaryExpression(let binaryExpression):
      return IULIABinaryExpression(binaryExpression: binaryExpression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .bracketedExpression(let expression):
      return IULIAExpression(expression: expression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .functionCall(let functionCall):
      return IULIAFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
    case .identifier(let identifier):
      return IULIAIdentifier(identifier: identifier, asLValue: asLValue).rendered(functionContext: functionContext)
    case .variableDeclaration(let variableDeclaration):
      return IULIAVariableDeclaration(variableDeclaration: variableDeclaration).rendered()
    case .literal(let literal):
      return IULIALiteralToken(literalToken: literal).rendered()
    case .arrayLiteral(let arrayLiteral):
      guard arrayLiteral.elements.count == 0 else { fatalError("Cannot render non-empty array literals yet") }
      return "0"
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return "0"
    case .self(let `self`):
      return IULIASelf(selfToken: self, asLValue: asLValue).rendered()
    case .subscriptExpression(let subscriptExpression):
      return IULIASubscriptExpression(subscriptExpression: subscriptExpression, asLValue: asLValue).rendered(functionContext: functionContext)
    }
  }
}

/// Generates code for a binary expression.
struct IULIABinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }
  
  func rendered(functionContext: FunctionContext) -> String {
    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return IULIAFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
      return IULIAPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue).rendered(functionContext: functionContext)
    }
    
    let lhs = IULIAExpression(expression: binaryExpression.lhs, asLValue: asLValue).rendered(functionContext: functionContext)
    let rhs = IULIAExpression(expression: binaryExpression.rhs, asLValue: asLValue).rendered(functionContext: functionContext)

    switch binaryExpression.opToken {
    case .equal:
      return IULIAAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs).rendered(functionContext: functionContext)

    case .plus: return "add(\(lhs), \(rhs))"
    case .minus: return "sub(\(lhs), \(rhs))"
    case .times: return "mul(\(lhs), \(rhs))"
    case .divide: return "div(\(lhs), \(rhs))"
    case .closeAngledBracket: return "gt(\(lhs), \(rhs))"
    case .openAngledBracket: return "lt(\(lhs), \(rhs))"
    case .doubleEqual: return "eq(\(lhs), \(rhs))"
    case .notEqual: return "iszero(eq(\(lhs), \(rhs)))"
    case .or: return "or(\(lhs), \(rhs))"
    case .and: return "and(\(lhs), \(rhs))"
    default: fatalError()
    }
  }
}

/// Generates code for a property access.
struct IULIAPropertyAccess {
  var lhs: Expression
  var rhs: Expression
  var asLValue: Bool
  
  func rendered(functionContext: FunctionContext) -> String {
    let lhsOffset: String
    
    let environment = functionContext.environment
    let scopeContext = functionContext.scopeContext
    let enclosingTypeName = functionContext.enclosingTypeName
    let isInContractFunction = functionContext.isInContractFunction
    
    if case .identifier(let lhsIdentifier) = lhs {
      if let enclosingType = lhs.enclosingType, let offset = environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingType) {
        lhsOffset = "\(offset)"
      } else {
        lhsOffset = "\(environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingTypeName)!)"
      }
    } else {
      lhsOffset = IULIAExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
    }
    
    let lhsType = environment.type(of: lhs, enclosingType: enclosingTypeName, scopeContext: scopeContext)
    let rhsOffset = IULIAPropertyOffset(expression: rhs, enclosingType: lhsType).rendered(functionContext: functionContext)
    
    let offset: String
    if !isInContractFunction {
      // For struct parameters, access the property by an offset to _flintSelf (the receiver's address).
      offset = "add(_flintSelf, \(rhsOffset))"
    } else {
      offset = "add(\(lhsOffset), \(rhsOffset))"
    }
    
    if asLValue {
      return offset
    }
    return "sload(\(offset))"
  }
}

/// Generates code for a property offset.
struct IULIAPropertyOffset {
  var expression: Expression
  var enclosingType: Type.RawType
  
  func rendered(functionContext: FunctionContext) -> String {
    if case .binaryExpression(let binaryExpression) = expression {
      return IULIAPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: true).rendered(functionContext: functionContext)
    }
    guard case .identifier(let identifier) = expression else { fatalError() }
    guard case .userDefinedType(let structIdentifier) = enclosingType else { fatalError() }
    
    return "\(functionContext.environment.propertyOffset(for: identifier.name, enclosingType: structIdentifier)!)"
  }
}

/// Generates code for an assignment.
struct IULIAAssignment {
  var lhs: Expression
  var rhs: Expression
  
  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> String {
    if !asTypeProperty {
      guard !functionContext.environment.type(of: rhs, enclosingType: functionContext.enclosingTypeName, scopeContext: functionContext.scopeContext).isDynamicType else {
        fatalError("Assigning dynamic types is not supported yet.")
      }
    }

    let rhsCode = IULIAExpression(expression: rhs).rendered(functionContext: functionContext)
    
    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      return "let \(Mangler.mangleName(variableDeclaration.identifier.name)) := \(rhsCode)"
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return "\(Mangler.mangleName(identifier.name)) := \(rhsCode)"
    default:
      // LHS refers to a storage property.
      let lhsCode = IULIAExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
      return "sstore(\(lhsCode), \(rhsCode))"
    }
  }
}

/// Generates code for a function call.
struct IULIAFunctionCall {
  var functionCall: FunctionCall
  
  func rendered(functionContext: FunctionContext) -> String {
    let environment = functionContext.environment
    
    if let eventInformation = environment.matchEventCall(functionCall, enclosingType: functionContext.enclosingTypeName) {
      return IULIAEventCall(eventCall: functionCall, eventInformation: eventInformation).rendered(functionContext: functionContext)
    }
    
    let args: String = functionCall.arguments.map({ argument in
      let type = environment.type(of: argument, enclosingType: functionContext.enclosingTypeName, scopeContext: functionContext.scopeContext)
      return IULIAExpression(expression: argument, asLValue: functionContext.environment.isReferenceType(type.name)).rendered(functionContext: functionContext)
    }).joined(separator: ", ")
    return "\(functionCall.identifier.name)(\(args))"
  }
}

/// Generates code for an event call.
struct IULIAEventCall {
  var eventCall: FunctionCall
  var eventInformation: PropertyInformation
  
  func rendered(functionContext: FunctionContext) -> String {
    let types = eventInformation.typeGenericArguments
    
    var stores = [String]()
    var memoryOffset = 0
    for (i, argument) in eventCall.arguments.enumerated() {
      let argument = IULIAExpression(expression: argument)
      stores.append("mstore(\(memoryOffset), \(argument))")
      memoryOffset += functionContext.environment.size(of: types[i]) * 32
    }
    
    let totalSize = types.reduce(0) { return $0 + functionContext.environment.size(of: $1) } * 32
    let typeList = eventInformation.typeGenericArguments.map { type in
      return "\(CanonicalType(from: type)!.rawValue)"
      }.joined(separator: ",")
    
    let eventHash = "\(eventCall.identifier.name)(\(typeList))".sha3(.keccak256)
    let log = "log1(0, \(totalSize), 0x\(eventHash))"
    
    return """
    \(stores.joined(separator: "\n"))
    \(log)
    """
  }
}

/// Generates code for an identifier.
struct IULIAIdentifier {
  var identifier: Identifier
  var asLValue: Bool

  init(identifier: Identifier, asLValue: Bool = false) {
    self.identifier = identifier
    self.asLValue = asLValue
  }
  
  func rendered(functionContext: FunctionContext) -> String {
    if let _ = identifier.enclosingType {
      return IULIAPropertyAccess(lhs: .self(Token(kind: .self, sourceLocation: identifier.sourceLocation)), rhs: .identifier(identifier), asLValue: asLValue).rendered(functionContext: functionContext)
    }
    return Mangler.mangleName(identifier.name)
  }

  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }
}

/// Generates code for a variable declaration.
struct IULIAVariableDeclaration {
  var variableDeclaration: VariableDeclaration
  
  func rendered() -> String {
    return "var \(variableDeclaration.identifier)"
  }
}

/// Generates code for a literal token.
struct IULIALiteralToken {
  var literalToken: Token

  func rendered() -> String {
    guard case .literal(let literal) = literalToken.kind else {
      fatalError("Unexpected token \(literalToken.kind).")
    }

    switch literal {
    case .boolean(let boolean): return boolean == .false ? "0" : "1"
    case .decimal(.real(let num1, let num2)): return "\(num1).\(num2)"
    case .decimal(.integer(let num)): return "\(num)"
    case .string(let string): return "\"\(string)\""
    }
  }
}

/// Generates code for a "self" expression.
struct IULIASelf {
  var selfToken: Token
  var asLValue: Bool
  
  func rendered() -> String {
    guard case .self = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    return asLValue ? "0" : ""
  }
}

/// Generates code for a subscript expression.
struct IULIASubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var asLValue: Bool
  
  func rendered(functionContext: FunctionContext) -> String {
    let baseIdentifier = subscriptExpression.baseIdentifier

    let environment = functionContext.environment

    let offset = environment.propertyOffset(for: subscriptExpression.baseIdentifier.name, enclosingType: subscriptExpression.baseIdentifier.enclosingType!)!
    let indexExpressionCode = IULIAExpression(expression: subscriptExpression.indexExpression).rendered(functionContext: functionContext)

    let type = environment.type(of: subscriptExpression.baseIdentifier.name, enclosingType: functionContext.enclosingTypeName)!

    guard let _ = baseIdentifier.enclosingType else {
      fatalError("Subscriptable types are only supported for contract properties right now.")
    }

    switch type {
    case .arrayType(let elementType):
      let storageArrayOffset = "\(IULIARuntimeFunction.storageArrayOffset.rawValue)(\(offset), \(indexExpressionCode))"
      if asLValue {
        return storageArrayOffset
      } else {
        guard environment.size(of: elementType) == 1 else {
          fatalError("Loading array elements of size > 1 is not supported yet.")
        }
        return "sload(\(storageArrayOffset))"
      }
    case .fixedSizeArrayType(let elementType, _):
      let typeSize = environment.size(of: type)
      let storageArrayOffset = "\(IULIARuntimeFunction.storageFixedSizeArrayOffset.rawValue)(\(offset), \(indexExpressionCode), \(typeSize))"
      if asLValue {
        return storageArrayOffset
      } else {
        guard environment.size(of: elementType) == 1 else {
          fatalError("Loading array elements of size > 1 is not supported yet.")
        }
        return "sload(\(storageArrayOffset))"
      }
    case .dictionaryType(key: let keyType, value: let valueType):
      guard environment.size(of: keyType) == 1 else {
        fatalError("Dictionary keys of size > 1 are not supported yet.")
      }

      let storageDictionaryOffsetForKey = "\(IULIARuntimeFunction.storageDictionaryOffsetForKey.rawValue)(\(offset), \(indexExpressionCode))"

      if asLValue {
        return "\(storageDictionaryOffsetForKey)"
      } else {
        guard environment.size(of: valueType) == 1 else {
          fatalError("Loading dictionary values of size > 1 is not supported yet.")
        }
        return "sload(\(storageDictionaryOffsetForKey))"
      }
    default: fatalError()
    }
  }
}
