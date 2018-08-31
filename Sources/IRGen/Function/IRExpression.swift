//
//  IRExpression.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer

/// Generates code for an expression.
struct IRExpression {
  var expression: Expression
  var asLValue: Bool

  init(expression: Expression, asLValue: Bool = false) {
    self.expression = expression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> String {
    switch expression {
    case .inoutExpression(let inoutExpression):
      return IRExpression(expression: inoutExpression.expression, asLValue: true).rendered(functionContext: functionContext)
    case .binaryExpression(let binaryExpression):
      return IRBinaryExpression(binaryExpression: binaryExpression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .bracketedExpression(let bracketedExpression):
      return IRExpression(expression: bracketedExpression.expression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .attemptExpression(let attemptExpression):
      return IRAttemptExpression(attemptExpression: attemptExpression).rendered(functionContext: functionContext)
    case .functionCall(let functionCall):
      return IRFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
    case .identifier(let identifier):
      return IRIdentifier(identifier: identifier, asLValue: asLValue).rendered(functionContext: functionContext)
    case .variableDeclaration(let variableDeclaration):
      return IRVariableDeclaration(variableDeclaration: variableDeclaration).rendered(functionContext: functionContext)
    case .literal(let literal):
      return IRLiteralToken(literalToken: literal).rendered()
    case .arrayLiteral(let arrayLiteral):
      for e in arrayLiteral.elements {
        guard case .arrayLiteral(_) = e else {
          fatalError("Cannot render non-empty array literals yet")
        }
      }
      return "0"
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return "0"
    case .self(let `self`):
      return IRSelf(selfToken: self, asLValue: asLValue).rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return IRSubscriptExpression(subscriptExpression: subscriptExpression, asLValue: asLValue).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      return expressions.map { IRExpression(expression: $0, asLValue: asLValue).rendered(functionContext: functionContext) }.joined(separator: "\n")
    case .rawAssembly(let assembly, _): return assembly
    case .range(_): fatalError("Range shouldn't be rendered directly")
    }
  }
}

/// Generates code for a binary expression.
struct IRBinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> String {
    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return IRFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
      return IRPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue).rendered(functionContext: functionContext)
    }

    let lhs = IRExpression(expression: binaryExpression.lhs, asLValue: asLValue).rendered(functionContext: functionContext)
    let rhs = IRExpression(expression: binaryExpression.rhs, asLValue: asLValue).rendered(functionContext: functionContext)

    switch binaryExpression.opToken {
    case .equal:
      return IRAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs).rendered(functionContext: functionContext)

    case .plus: return IRRuntimeFunction.add(a: lhs, b: rhs)
    case .overflowingPlus: return "add(\(lhs), \(rhs))"
    case .minus: return IRRuntimeFunction.sub(a: lhs, b: rhs)
    case .overflowingMinus: return "sub(\(lhs), \(rhs))"
    case .times: return IRRuntimeFunction.mul(a: lhs, b: rhs)
    case .overflowingTimes: return "mul(\(lhs), \(rhs))"
    case .divide: return IRRuntimeFunction.div(a: lhs, b: rhs)
    case .closeAngledBracket: return "gt(\(lhs), \(rhs))"
    case .openAngledBracket: return "lt(\(lhs), \(rhs))"
    case .doubleEqual: return "eq(\(lhs), \(rhs))"
    case .notEqual: return "iszero(eq(\(lhs), \(rhs)))"
    case .or: return "or(\(lhs), \(rhs))"
    case .and: return "and(\(lhs), \(rhs))"
    case .power: return IRRuntimeFunction.power(b: lhs, e: rhs)
    default: fatalError("opToken not supported")
    }
  }
}

/// Generates code for a property access.
struct IRPropertyAccess {
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

    if case .identifier(let enumIdentifier) = lhs,
      case .identifier(let propertyIdentifier) = rhs,
      environment.isEnumDeclared(enumIdentifier.name),
      let propertyInformation = environment.property(propertyIdentifier.name, enumIdentifier.name) {
      return IRExpression(expression: propertyInformation.property.value!).rendered(functionContext: functionContext)
    }

    let rhsOffset: String
    // Special cases.
    switch lhsType {
    case .fixedSizeArrayType(_, let size):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        return "\(size)"
      } else {
        fatalError()
      }
    case .arrayType(_):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = "0"
      } else {
        fatalError()
      }
    case .dictionaryType(_):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = "0"
      } else {
        fatalError()
      }
    default:
      rhsOffset = IRPropertyOffset(expression: rhs, enclosingType: lhsType).rendered(functionContext: functionContext)
    }

    let offset: String
    if isInStructFunction {
      let enclosingName: String
      if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
        enclosingName = enclosingParameter
      } else {
        enclosingName = "flintSelf"
      }

      // For struct parameters, access the property by an offset to _flintSelf (the receiver's address).
      offset = IRRuntimeFunction.addOffset(base: enclosingName.mangled, offset: rhsOffset, inMemory: Mangler.isMem(for: enclosingName).mangled)
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
        lhsOffset = IRExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
      }

      offset = IRRuntimeFunction.addOffset(base: lhsOffset, offset: rhsOffset, inMemory: isMemoryAccess)
    }

    if asLValue {
      return offset
    }

    if isInStructFunction, !isMemoryAccess {
      let lhsEnclosingIdentifier = lhs.enclosingIdentifier?.name.mangled ?? "flintSelf".mangled
      return IRRuntimeFunction.load(address: offset, inMemory: Mangler.isMem(for: lhsEnclosingIdentifier))
    }

    return IRRuntimeFunction.load(address: offset, inMemory: isMemoryAccess)
  }
}

/// Generates code for a property offset.
struct IRPropertyOffset {
  var expression: Expression
  var enclosingType: RawType

  func rendered(functionContext: FunctionContext) -> String {
    if case .binaryExpression(let binaryExpression) = expression {
      return IRPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: true).rendered(functionContext: functionContext)
    } else if case .subscriptExpression(let subscriptExpression) = expression {
      return IRSubscriptExpression(subscriptExpression: subscriptExpression, asLValue: true).rendered(functionContext: functionContext)
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
struct IRAssignment {
  var lhs: Expression
  var rhs: Expression

  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> String {
    let rhsCode = IRExpression(expression: rhs).rendered(functionContext: functionContext)

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      return "let \(Mangler.mangleName(variableDeclaration.identifier.name)) := \(rhsCode)"
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return "\(identifier.name.mangled) := \(rhsCode)"
    default:
      // LHS refers to a property in storage or memory.
      let lhsCode = IRExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)

      if functionContext.isInStructFunction {
        let enclosingName: String
        if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
          enclosingName = enclosingParameter
        } else {
          enclosingName = "flintSelf"
        }
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: Mangler.isMem(for: enclosingName).mangled)
      } else if let enclosingIdentifier = lhs.enclosingIdentifier,
        functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: true)
      } else {
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: false)
      }
    }
  }
}

/// Generates code for a function call.
struct IRFunctionCall {
  var functionCall: FunctionCall

  func rendered(functionContext: FunctionContext) -> String {
    let environment = functionContext.environment

    if let eventInformation = environment.matchEventCall(functionCall, enclosingType: functionContext.enclosingTypeName) {
      return IREventCall(eventCall: functionCall, eventInformation: eventInformation).rendered(functionContext: functionContext)
    }

    let args: String = functionCall.arguments.map({ argument in
      return IRExpression(expression: argument, asLValue: false).rendered(functionContext: functionContext)
    }).joined(separator: ", ")
    let identifier = functionCall.mangledIdentifier ?? functionCall.identifier.name
    return "\(identifier)(\(args))"
  }

}

/// Generates code for an event call.
struct IREventCall {
  var eventCall: FunctionCall
  var eventInformation: PropertyInformation

  func rendered(functionContext: FunctionContext) -> String {
    let types = eventInformation.typeGenericArguments

    var stores = [String]()
    var memoryOffset = 0
    for (i, argument) in eventCall.arguments.enumerated() {
      let argument = IRExpression(expression: argument).rendered(functionContext: functionContext)
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
struct IRIdentifier {
  var identifier: Identifier
  var asLValue: Bool

  init(identifier: Identifier, asLValue: Bool = false) {
    self.identifier = identifier
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> String {
    if let _ = identifier.enclosingType {
      return IRPropertyAccess(lhs: .self(Token(kind: .self, sourceLocation: identifier.sourceLocation)), rhs: .identifier(identifier), asLValue: asLValue).rendered(functionContext: functionContext)
    }
    return identifier.name.mangled
  }

  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }
}

/// Generates code for a variable declaration.
struct IRVariableDeclaration {
  var variableDeclaration: VariableDeclaration

  func rendered(functionContext: FunctionContext) -> String {
    let allocate = IRRuntimeFunction.allocateMemory(size: functionContext.environment.size(of: variableDeclaration.type.rawType) * EVM.wordSize)
    return "let \(variableDeclaration.identifier.name.mangled) := \(allocate)"
  }
}

/// Generates code for a literal token.
struct IRLiteralToken {
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
    case .address(let hex): return hex
    }
  }
}

// Generates code for an attempt expression
struct IRAttemptExpression {
   var attemptExpression: AttemptExpression

   func rendered(functionContext: FunctionContext) -> String {
     let functionCall = attemptExpression.functionCall
     let functionName = functionCall.mangledIdentifier ?? functionCall.identifier.name

     let callName: String
     if case .hard = attemptExpression.kind {
       callName = IRWrapperFunction.prefixHard + functionName
     } else {
       callName = IRWrapperFunction.prefixSoft + functionName
     }

     let args: String = functionCall.arguments.map({ argument in
       return IRExpression(expression: argument, asLValue: false).rendered(functionContext: functionContext)
     }).joined(separator: ", ")

     return "\(callName)(\(args))"

   }
 }

/// Generates code for a "self" expression.
struct IRSelf {
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
struct IRSubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var asLValue: Bool

  func baseIdentifier(_ baseExpression: Expression) -> AST.Identifier? {
    if case .identifier(let identifier) = baseExpression {
      return identifier
    }
    if case .subscriptExpression(let subscriptExpression) = baseExpression {
      return baseIdentifier(subscriptExpression.baseExpression)
    }
    return nil
  }

  func nestedStorageOffset(subExpr: SubscriptExpression, baseOffset: Int, functionContext: FunctionContext) -> String {
    let indexExpressionCode = IRExpression(expression: subExpr.indexExpression).rendered(functionContext: functionContext)

    let type = functionContext.environment.type(of: subExpr.baseExpression, enclosingType: functionContext.enclosingTypeName, scopeContext: functionContext.scopeContext)
    let runtimeFunc: (String, String) -> String

    switch type {
    case .arrayType(_):
      runtimeFunc = IRRuntimeFunction.storageArrayOffset
    case .fixedSizeArrayType(_):
      let typeSize = functionContext.environment.size(of: type)
      runtimeFunc = {IRRuntimeFunction.storageFixedSizeArrayOffset(arrayOffset: $0, index: $1, arraySize: typeSize)}
    case .dictionaryType(_):
      runtimeFunc = IRRuntimeFunction.storageDictionaryOffsetForKey
    default: fatalError("Invalid type")
    }

    switch subExpr.baseExpression {
    case .identifier(_):
      return runtimeFunc(String(baseOffset), indexExpressionCode)
    case .subscriptExpression(let newBase):
      return runtimeFunc(nestedStorageOffset(subExpr: newBase, baseOffset: baseOffset, functionContext: functionContext), indexExpressionCode)
    default:
      fatalError("Subscript expression has an invalid type")
    }
  }

  func rendered(functionContext: FunctionContext) -> String {
    guard let identifier = baseIdentifier(.subscriptExpression(subscriptExpression)),
      let enclosingType = identifier.enclosingType,
      let baseOffset = functionContext.environment.propertyOffset(for: identifier.name, enclosingType: enclosingType) else {
        fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    }

    let memLocation: String = nestedStorageOffset(subExpr: subscriptExpression, baseOffset: baseOffset, functionContext: functionContext)

    if asLValue {
      return memLocation
    }
    else {
      return "sload(\(memLocation))"
    }
  }
}
