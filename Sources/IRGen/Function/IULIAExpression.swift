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
      return IULIAVariableDeclaration(variableDeclaration: variableDeclaration).rendered(functionContext: functionContext)
    case .literal(let literal):
      return IULIALiteralToken(literalToken: literal).rendered()
    case .arrayLiteral(let arrayLiteral):
      guard arrayLiteral.elements.count == 0 else { fatalError("Cannot render non-empty array literals yet") }
      return "0"
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return "0"
    case .self(let `self`):
      return IULIASelf(selfToken: self, asLValue: asLValue).rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return IULIASubscriptExpression(subscriptExpression: subscriptExpression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      return expressions.map { IULIAExpression(expression: $0, asLValue: asLValue).rendered(functionContext: functionContext) }.joined(separator: "\n")
    case .rawAssembly(let assembly, _): return assembly
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
    let environment = functionContext.environment
    let scopeContext = functionContext.scopeContext
    let enclosingTypeName = functionContext.enclosingTypeName
    let isInStructFunction = functionContext.isInStructFunction

    var isMemoryAccess: Bool = false
    
    let lhsType = environment.type(of: lhs, enclosingType: enclosingTypeName, scopeContext: scopeContext)
    let rhsOffset = IULIAPropertyOffset(expression: rhs, enclosingType: lhsType).rendered(functionContext: functionContext)
    
    let offset: String
    if isInStructFunction {
      let enclosingName: String
      if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
        enclosingName = enclosingParameter
      } else {
        enclosingName = "flintSelf"
      }

      // For struct parameters, access the property by an offset to _flintSelf (the receiver's address).
      offset = IULIARuntimeFunction.addOffset(base: enclosingName.mangled, offset: rhsOffset, inMemory: Mangler.isMem(for: enclosingName).mangled)
    } else {
      let lhsOffset: String
      if case .identifier(let lhsIdentifier) = lhs {
        if let enclosingType = lhsIdentifier.enclosingType, let offset = environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingType) {
          lhsOffset = "\(offset)"
        } else if functionContext.scopeContext.containsVariableDeclaration(for: lhsIdentifier.name) {
          lhsOffset = lhsIdentifier.name.mangled
          isMemoryAccess = true
        } else {
          lhsOffset = "\(environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingTypeName)!)"
        }
      } else {
        lhsOffset = IULIAExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
      }

      offset = IULIARuntimeFunction.addOffset(base: lhsOffset, offset: rhsOffset, inMemory: isMemoryAccess)
    }
    
    if asLValue {
      return offset
    }

    if isInStructFunction, !isMemoryAccess {
      let lhsEnclosingIdentifier = lhs.enclosingIdentifier?.name.mangled ?? "flintSelf".mangled
      return IULIARuntimeFunction.load(address: offset, inMemory: Mangler.isMem(for: lhsEnclosingIdentifier))
    }

    return IULIARuntimeFunction.load(address: offset, inMemory: isMemoryAccess)
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

    let structIdentifier: String

    switch enclosingType {
    case .stdlibType(let type): structIdentifier = type.rawValue
    case .userDefinedType(let type): structIdentifier = type
    default: fatalError()
    }
    
    return "\(functionContext.environment.propertyOffset(for: identifier.name, enclosingType: structIdentifier)!)"
  }
}

/// Generates code for an assignment.
struct IULIAAssignment {
  var lhs: Expression
  var rhs: Expression
  
  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> String {
    let rhsCode = IULIAExpression(expression: rhs).rendered(functionContext: functionContext)
    
    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      return "let \(Mangler.mangleName(variableDeclaration.identifier.name)) := \(rhsCode)"
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return "\(identifier.name.mangled) := \(rhsCode)"
    default:
      // LHS refers to a property in storage or memory.

      let lhsCode = IULIAExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)

      if functionContext.isInStructFunction {
        let enclosingName: String
        if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
          enclosingName = enclosingParameter
        } else {
          enclosingName = "flintSelf"
        }
        return IULIARuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: Mangler.isMem(for: enclosingName).mangled)
      }

      let isMemoryAccess: Bool
      if let enclosingIdentifier = lhs.enclosingIdentifier, functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        isMemoryAccess = true
      } else {
        isMemoryAccess = false
      }

      return IULIARuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: isMemoryAccess)
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
      return IULIAExpression(expression: argument, asLValue: false).rendered(functionContext: functionContext)
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
      let argument = IULIAExpression(expression: argument).rendered(functionContext: functionContext)
      stores.append("mstore(\(memoryOffset), \(argument))")
      memoryOffset += functionContext.environment.size(of: types[i]) * EVM.wordSize
    }
    
    let totalSize = types.reduce(0) { return $0 + functionContext.environment.size(of: $1) } * EVM.wordSize
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
    return identifier.name.mangled
  }

  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }
}

/// Generates code for a variable declaration.
struct IULIAVariableDeclaration {
  var variableDeclaration: VariableDeclaration
  
  func rendered(functionContext: FunctionContext) -> String {
    let allocate = IULIARuntimeFunction.allocateMemory(size: functionContext.environment.size(of: variableDeclaration.type.rawType) * EVM.wordSize)
    return "let \(variableDeclaration.identifier.name.mangled) := \(allocate)"
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
  
  func rendered(functionContext: FunctionContext) -> String {
    guard case .self = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }

    return functionContext.isInStructFunction ? "_flintSelf" : asLValue ? "0" : ""
  }
}

/// Generates code for a subscript expression.
struct IULIASubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var asLValue: Bool
  
  func rendered(functionContext: FunctionContext) -> String {
    let baseIdentifier = subscriptExpression.baseIdentifier

    let environment = functionContext.environment

    guard let enclosingType = subscriptExpression.baseIdentifier.enclosingType,
      let offset = environment.propertyOffset(for: subscriptExpression.baseIdentifier.name, enclosingType: enclosingType) else {
      fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    }

    let indexExpressionCode = IULIAExpression(expression: subscriptExpression.indexExpression).rendered(functionContext: functionContext)

    let type = environment.type(of: subscriptExpression.baseIdentifier.name, enclosingType: functionContext.enclosingTypeName)

    guard let _ = baseIdentifier.enclosingType else {
      fatalError("Subscriptable types are only supported for contract properties right now.")
    }

    switch type {
    case .arrayType(let elementType):
      let storageArrayOffset = IULIARuntimeFunction.storageArrayOffset(arrayOffset: offset, index: indexExpressionCode)
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
      let storageArrayOffset = IULIARuntimeFunction.storageFixedSizeArrayOffset(arrayOffset: offset, index: indexExpressionCode, arraySize: typeSize)
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

      let storageDictionaryOffsetForKey = IULIARuntimeFunction.storageDictionaryOffsetForKey(dictionaryOffset: offset, key: indexExpressionCode)

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
