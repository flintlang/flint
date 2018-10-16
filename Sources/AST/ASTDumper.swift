//
//  ASTDumper.swift
//  AST
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation
import Lexer

/// Prints an AST.
public class ASTDumper {
  var topLevelModule: TopLevelModule
  var indentation = 0
  var output = ""

  public init(topLevelModule: TopLevelModule) {
    self.topLevelModule = topLevelModule
  }

  public func dump() -> String {
    dump(topLevelModule)
    return output
  }

  func writeNode(_ node: String, contents: (() -> Void)? = nil) {
    output += String(repeating: " ", count: indentation)
    output += "\(node) (\n"
    indentation += 2
    contents?()
    indentation -= 2
    output += String(repeating: " ", count: indentation)
    output += ")\n"
  }

  func writeLine(_ line: String) {
    output += String(repeating: " ", count: indentation)
    output += line + "\n"
  }

  func dump(_ topLevelModule: TopLevelModule) {
    writeNode("TopLevelModule") {
      for declaration in topLevelModule.declarations {
        self.dump(declaration)
      }
    }
  }

  func dump(_ topLevelDeclaration: TopLevelDeclaration) {
    writeNode("TopLevelDeclaration") {
      switch topLevelDeclaration {
      case .contractDeclaration(let contractDeclaration):
        self.dump(contractDeclaration)
      case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
        self.dump(contractBehaviorDeclaration)
      case .structDeclaration(let structDeclaration):
        self.dump(structDeclaration)
      case .enumDeclaration(let enumDeclaration):
        self.dump(enumDeclaration)
      case .traitDeclaration(let traitDeclaration):
        self.dump(traitDeclaration)
      }
    }
  }

  func dump(_ contractDeclaration: ContractDeclaration) {
    writeNode("ContractDeclaration") {
      self.dump(contractDeclaration.contractToken)
      self.dump(contractDeclaration.identifier)
      if !contractDeclaration.conformances.isEmpty {
        self.dump(contractDeclaration.conformances)
      }
      if !contractDeclaration.states.isEmpty {
        self.dump(contractDeclaration.states)
      }
      for member in contractDeclaration.members {
        self.dump(member)
      }
    }
  }

  func dump(_ states: [TypeState]) {
    writeNode("States") {
      for state in states {
        self.dump(state)
      }
    }
  }

  func dump(_ conformances: [Conformance]) {
    writeNode("Conforms to") {
      for trait in conformances {
        self.dump(trait.identifier)
      }
    }
  }

  func dump(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    writeNode("ContractBehaviorDeclaration") {
      self.dump(contractBehaviorDeclaration.contractIdentifier)
      if let callerBinding = contractBehaviorDeclaration.callerBinding {
        self.writeLine("caller binding \"\(callerBinding.name)\"")
      }

      self.dump(contractBehaviorDeclaration.states)

      for callerProtection in contractBehaviorDeclaration.callerProtections {
        self.dump(callerProtection)
      }
      for member in contractBehaviorDeclaration.members {
        self.dump(member)
      }
      self.dump(contractBehaviorDeclaration.closeBracketToken)
    }
  }

  func dump(_ structDeclaration: StructDeclaration) {
    writeNode("StructDeclaration") {
      self.dump(structDeclaration.identifier)
      if !structDeclaration.conformances.isEmpty {
        self.dump(structDeclaration.conformances)
      }
      for member in structDeclaration.members {
        self.dump(member)
      }
    }
  }

  func dump(_ eventDeclaration: EventDeclaration) {
    writeNode("EventDeclaration") {
      self.dump(eventDeclaration.identifier)

      for variable in eventDeclaration.variableDeclarations {
        self.dump(variable)
      }
    }
  }

  func dump(_ enumDeclaration: EnumDeclaration) {
    writeNode("EnumDeclaration") {
      self.dump(enumDeclaration.identifier)
      self.dump(enumDeclaration.type)
      self.writeNode("Cases") {
        for enumCase in enumDeclaration.cases {
          self.dump(enumCase)
        }
      }
    }
  }

  func dump(_ enumCase: EnumMember) {
    writeNode("EnumCase") {
      self.dump(enumCase.identifier)
      if let rawValue = enumCase.hiddenValue {
        self.dump(rawValue)
      }
    }
  }

  func dump(_ traitDeclaration: TraitDeclaration) {
    writeNode("TraitDeclaration") {
      self.dump(traitDeclaration.traitKind)
      self.dump(traitDeclaration.identifier)
      for member in traitDeclaration.members {
        self.dump(member)
      }
    }
  }

  func dump(_ traitMember: TraitMember) {
    switch traitMember {
    case .functionDeclaration(let functionDeclaration):
      self.dump(functionDeclaration)
    case .functionSignatureDeclaration(let functionSignatureDeclaration):
      self.dump(functionSignatureDeclaration)
    case .specialDeclaration(let specialDeclaration):
      self.dump(specialDeclaration)
    case .specialSignatureDeclaration(let specialSignatureDeclaration):
      self.dump(specialSignatureDeclaration)
    case .eventDeclaration(let eventDeclaration):
      self.dump(eventDeclaration)
    case .contractBehaviourDeclaration(let contractBehaviorDeclaration):
      self.dump(contractBehaviorDeclaration)
    }
  }

  func dump(_ structMember: StructMember) {
    switch structMember {
    case .functionDeclaration(let functionDeclaration):
      self.dump(functionDeclaration)
    case .variableDeclaration(let variableDeclaration):
      self.dump(variableDeclaration)
    case .specialDeclaration(let specialDeclaration):
      self.dump(specialDeclaration)
    }
  }

  func dump(_ contractMember: ContractMember) {
    switch contractMember {
    case .variableDeclaration(let variableDeclaration):
      self.dump(variableDeclaration)
    case .eventDeclaration(let eventDeclaration):
      self.dump(eventDeclaration)
    }
  }

  func dump(_ contractBehaviorMember: ContractBehaviorMember) {
    switch contractBehaviorMember {
    case .functionDeclaration(let decl):
      self.dump(decl)
    case .specialDeclaration(let decl):
      self.dump(decl)
    case .functionSignatureDeclaration(let decl):
      self.dump(decl)
    case .specialSignatureDeclaration(let decl):
      self.dump(decl)
    }
  }

  func dump(_ variableDeclaration: VariableDeclaration) {
    writeNode("VariableDeclaration") {
      if let declarationToken = variableDeclaration.declarationToken {
        self.dump(declarationToken)
      }
      for modifier in variableDeclaration.modifiers {
        self.dump(modifier)
      }
      self.dump(variableDeclaration.identifier)
      self.dump(variableDeclaration.type)

      if let assignedExpression = variableDeclaration.assignedExpression {
        self.dump(assignedExpression)
      }
    }
  }

  func dump(_ functionDeclaration: FunctionDeclaration) {
    writeNode("FunctionDeclaration") {
      self.dumpNodeContents(functionDeclaration)
    }
  }

  func dump(_ functionSignatureDeclaration: FunctionSignatureDeclaration) {
    writeNode("FunctionSignatureDeclaration") {
      self.dumpNodeContents(functionSignatureDeclaration)
    }
  }

  func dump(_ specialDeclaration: SpecialDeclaration) {
    writeNode("SpecialDeclaration") {
      self.dumpNodeContents(specialDeclaration.asFunctionDeclaration)
    }
  }

  func dump(_ specialSignatureDeclaration: SpecialSignatureDeclaration) {
    writeNode("SpecialSignatureDeclaration") {
      self.dumpNodeContents(specialSignatureDeclaration.asFunctionSignatureDeclaration)
    }
  }

  func dumpNodeContents(_ functionDeclaration: FunctionDeclaration) {
    self.dumpNodeContents(functionDeclaration.signature)

    for statement in functionDeclaration.body {
      self.dump(statement)
    }
  }

  func dumpNodeContents(_ functionSignatureDeclaration: FunctionSignatureDeclaration) {
    for attribute in functionSignatureDeclaration.attributes {
      self.dump(attribute)
    }

    for modifier in functionSignatureDeclaration.modifiers {
      self.dump(modifier)
    }

    self.dump(functionSignatureDeclaration.funcToken)

    self.dump(functionSignatureDeclaration.identifier)

    for parameter in functionSignatureDeclaration.parameters {
      self.dump(parameter)
    }

    self.dump(functionSignatureDeclaration.closeBracketToken)

    if let resultType = functionSignatureDeclaration.resultType {
      self.writeNode("ResultType") {
        self.dump(resultType)
      }
    }
  }

  func dump(_ parameter: Parameter) {
    writeNode("Parameter") {
      if parameter.isImplicit {
        self.writeLine("implicit")
      }
      self.dump(parameter.identifier)
      if parameter.isInout {
        self.writeLine("inout")
      }
      self.dump(parameter.type)
    }
  }

  func dump(_ attribute: Attribute) {
    writeNode("Attribute") {
      self.writeLine("attribute \(attribute.kind.rawValue)")
    }
  }

  func dump(_ typeAnnotation: TypeAnnotation) {
    writeNode("TypeAnnotation") {
      self.dump(typeAnnotation.colonToken)
      self.dump(typeAnnotation.type)
    }
  }

  func dump(_ identifer: Identifier) {
    writeNode("Identifier") {
      self.dump(identifer.identifierToken)
    }
  }

  func dump(_ type: Type) {
    writeNode("Type") {
      self.dump(type.rawType)
      self.writeNode("Generic Arguments") {
        for type in type.genericArguments {
          self.dump(type)
        }
      }
    }
  }

  func dump(_ rawType: RawType) {
    switch rawType {
    case .fixedSizeArrayType(let rawType, size: let size):
      writeNode("FixedSizeArrayType") {
        self.dump(rawType)
        self.writeLine("size \(size)")
      }
    case .arrayType(let rawType):
      writeNode("ArrayType") {
        self.dump(rawType)
      }
    case .rangeType(let rawType):
      writeNode("RangeType") {
        self.dump(rawType)
      }
    case .dictionaryType(key: let keyType, value: let valueType):
      self.writeNode("DictionaryType") {
        self.dump(keyType)
        self.dump(valueType)
      }
    case .basicType(let rawType):
      writeNode("BasicType") {
        self.dump(rawType)
      }
    case .stdlibType(let type):
      writeLine("Stdlib type \(type.rawValue)")
    case .userDefinedType(let userDefinedType):
      writeLine("user-defined type \(userDefinedType)")
    case .inoutType(let rawType):
      writeNode("inout type") {
        self.dump(rawType)
      }
    case .selfType:
      writeNode("Self type")
    case .any:
      writeLine("Any")
    case .errorType:
      writeLine("Flint error type \(rawType.name)")
    case .functionType:
      writeLine("function type \(rawType.name)")
    }
  }

  func dump(_ builtInType: RawType.BasicType) {
    writeLine("built-in type \(builtInType.rawValue)")
  }

  func dump(_ callerProtection: CallerProtection) {
    writeNode("CallerProtection") {
      self.dump(callerProtection.identifier)
    }
  }

  func dump(_ typeState: TypeState) {
    writeNode("TypeState") {
      self.dump(typeState.identifier)
    }
  }

  func dump(_ expression: Expression) {
    writeNode("Expression") {
      switch expression {
      case .inoutExpression(let inoutExpression): self.dump(inoutExpression)
      case .binaryExpression(let binaryExpression): self.dump(binaryExpression)
      case .bracketedExpression(let bracketedExpression): self.dump(bracketedExpression)
      case .functionCall(let functionCall): self.dump(functionCall)
      case .identifier(let identifier): self.dump(identifier)
      case .literal(let token): self.dump(token)
      case .arrayLiteral(let arrayLiteral): self.dump(arrayLiteral)
      case .dictionaryLiteral(let dictionaryLiteral): self.dump(dictionaryLiteral)
      case .self(let token): self.dump(token)
      case .variableDeclaration(let variableDeclaration): self.dump(variableDeclaration)
      case .subscriptExpression(let subscriptExpression): self.dump(subscriptExpression)
      case .attemptExpression(let attemptExpression): self.dump(attemptExpression)
      case .sequence(let expressions): expressions.forEach { self.dump($0) }
      case .range(let rangeExpression): self.dump(rangeExpression)
      case .rawAssembly: fatalError()
      }
    }
  }

  func dump(_ statement: Statement) {
    writeNode("Statement") {
      switch statement {
      case .expression(let expression): self.dump(expression)
      case .returnStatement(let returnStatement): self.dump(returnStatement)
      case .becomeStatement(let becomeStatement): self.dump(becomeStatement)
      case .ifStatement(let ifStatement): self.dump(ifStatement)
      case .forStatement(let forStatement): self.dump(forStatement)
      case .emitStatement(let emitStatement): self.dump(emitStatement)
      }
    }
  }

  func dump(_ inoutExpression: InoutExpression) {
    writeNode("InoutExpression") {
      self.dump(inoutExpression.expression)
    }
  }

  func dump(_ binaryExpression: BinaryExpression) {
    writeNode("BinaryExpression") {
      self.dump(binaryExpression.lhs)
      self.dump(binaryExpression.op)
      self.dump(binaryExpression.rhs)
    }
  }

  func dump(_ bracketedExpression: BracketedExpression) {
    writeNode("BracketedExpression") {
      self.dump(bracketedExpression.expression)
    }
  }

  func dump(_ functionArgument: FunctionArgument) {
    writeNode("FunctionArgument") {
      if let identifier = functionArgument.identifier {
           self.dump(identifier)
       }
       self.dump(functionArgument.expression)
    }
  }

  func dump(_ functionCall: FunctionCall) {
    writeNode("FunctionCall") {
      self.dump(functionCall.identifier)
      for argument in functionCall.arguments {
        self.dump(argument)
      }

      self.dump(functionCall.closeBracketToken)
    }
  }

  func dump(_ subscriptExpression: SubscriptExpression) {
    writeNode("SubscriptExpression") {
      self.dump(subscriptExpression.baseExpression)
      self.dump(subscriptExpression.indexExpression)
      self.dump(subscriptExpression.closeSquareBracketToken)
    }
  }

  func dump(_ attemptExpression: AttemptExpression) {
    writeNode("AttemptExpression") {
       self.dump(attemptExpression.tryToken)
       self.writeLine("kind: " + attemptExpression.kind.rawValue)
       self.dump(attemptExpression.functionCall)
     }
  }

  func dump(_ returnStatement: ReturnStatement) {
    writeNode("ReturnStatement") {
      self.dump(returnStatement.returnToken)

      if let expression = returnStatement.expression {
        self.dump(expression)
      }
    }
  }

  func dump(_ becomeStatement: BecomeStatement) {
    writeNode("BecomeStatement") {
      self.dump(becomeStatement.becomeToken)
      self.dump(becomeStatement.expression)
    }
  }

  func dump(_ emitStatement: EmitStatement) {
    writeNode("EmitStatement") {
      self.dump(emitStatement.emitToken)
      self.dump(emitStatement.expression)
    }
  }

  func dump(_ ifStatement: IfStatement) {
    writeNode("IfStatement") {
      self.dump(ifStatement.ifToken)
      self.dump(ifStatement.condition)

      for statement in ifStatement.body {
        self.dump(statement)
      }

      self.writeNode("ElseBlock") {
        for statement in ifStatement.elseBody {
          self.dump(statement)
        }
      }
    }
  }

  func dump(_ forStatement: ForStatement) {
    writeNode("ForStatement") {
      self.dump(forStatement.forToken)
      self.dump(forStatement.variable)
      self.dump(forStatement.iterable)
      for statement in forStatement.body {
        self.dump(statement)
      }
    }
  }

  func dump(_ token: Token) {
    writeLine("token: \(token.kind.description)")
  }

  func dump(_ arrayLiteral: ArrayLiteral) {
    writeNode("ArrayLiteral") {
      for element in arrayLiteral.elements {
        self.dump(element)
      }
    }
  }

  func dump(_ rangeExpression: RangeExpression) {
    writeNode("RangeExpression") {
      self.dump(rangeExpression.initial)
      self.dump(rangeExpression.op)
      self.dump(rangeExpression.bound)
    }
  }

  func dump(_ dictionaryLiteral: DictionaryLiteral) {
    writeNode("DictionaryLiteral") {
      for element in dictionaryLiteral.elements {
        self.dump(element.key)
        self.dump(element.value)
      }
    }
  }
}
