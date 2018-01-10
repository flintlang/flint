//
//  ASTDumper.swift
//  flintc
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation

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

  func writeNode(_ node: String, contents: (() -> ())? = nil) {
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
      }
    }
  }

  func dump(_ contractDeclaration: ContractDeclaration) {
    writeNode("ContractDeclaration") {
      self.dump(contractDeclaration.contractToken)
      self.dump(contractDeclaration.identifier)

      for variableDeclaration in contractDeclaration.variableDeclarations {
        self.dump(variableDeclaration)
      }
    }
  }

  func dump(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    writeNode("ContractBehaviorDeclaration") {
      self.dump(contractBehaviorDeclaration.contractIdentifier)
      for callerCapability in contractBehaviorDeclaration.callerCapabilities {
        self.dump(callerCapability)
      }
      for functionDeclaration in contractBehaviorDeclaration.functionDeclarations {
        self.dump(functionDeclaration)
      }
      self.dump(contractBehaviorDeclaration.closeBracketToken)
    }
  }

  func dump(_ variableDeclaration: VariableDeclaration) {
    writeNode("VariableDeclaration") {
      self.dump(variableDeclaration.varToken)
      self.dump(variableDeclaration.identifier)
      self.dump(variableDeclaration.type)
    }
  }

  func dump(_ functionDeclaration: FunctionDeclaration) {
    writeNode("FunctionDeclaration") {
      self.dump(functionDeclaration.funcToken)

      for modifier in functionDeclaration.modifiers {
        self.dump(modifier)
      }

      self.dump(functionDeclaration.identifier)

      for parameter in functionDeclaration.parameters {
        self.dump(parameter)
      }

      self.dump(functionDeclaration.closeBracketToken)

      if let resultType = functionDeclaration.resultType {
        self.writeNode("ResultType") {
          self.dump(resultType)
        }
      }

      for statement in functionDeclaration.body {
        self.dump(statement)
      }
    }
  }

  func dump(_ parameter: Parameter) {
    writeNode("Parameter") {
      self.dump(parameter.identifier)
      self.dump(parameter.type)
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
    }
  }

  func dump(_ rawType: Type.RawType) {
    switch rawType {
    case .arrayType(let rawType, size: let size):
      self.writeNode("ArrayType") {
        self.dump(rawType)
        self.writeLine("size: \(size)")
      }
    case .dictionaryType(key: let keyType, value: let valueType):
      self.writeNode("DictionaryType") {
        self.dump(keyType)
        self.dump(valueType)
      }
    case .builtInType(let builtInType):
      self.writeNode("BuiltInType") {
        self.dump(builtInType)
      }
    case .userDefinedType(let userDefinedType):
      self.writeLine("user-defined type: \(userDefinedType)")
    }
  }

  func dump(_ builtInType: Type.BuiltInType) {
    switch builtInType {
    case .address: writeLine("built-in type: Address")
    }
  }

  func dump(_ callerCapability: CallerCapability) {
    writeNode("CallerCapability") {
      self.dump(callerCapability.identifier)
    }
  }

  func dump(_ expression: Expression) {
    writeNode("Expression") {
      switch expression {
      case .binaryExpression(let binaryExpression): self.dump(binaryExpression)
      case .bracketedExpression(let expression): self.dump(expression)
      case .functionCall(let functionCall): self.dump(functionCall)
      case .identifier(let identifier): self.dump(identifier)
      case .literal(let token): self.dump(token)
      case .self(let token): self.dump(token)
      case .variableDeclaration(let variableDeclaration): self.dump(variableDeclaration)
      case .subscriptExpression(let subscriptExpression): self.dump(subscriptExpression)
      }
    }
  }

  func dump(_ statement: Statement) {
    writeNode("Statement") {
      switch statement {
      case .expression(let expression): self.dump(expression)
      case .returnStatement(let returnStatement): self.dump(returnStatement)
      case .ifStatement(let ifStatement): self.dump(ifStatement)
      }
    }
  }

  func dump(_ binaryExpression: BinaryExpression) {
    writeNode("BinaryExpression") {
      self.dump(binaryExpression.lhs)
      self.dump(binaryExpression.op)
      self.dump(binaryExpression.rhs)
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
      self.dump(subscriptExpression.baseIdentifier)
      self.dump(subscriptExpression.indexExpression)
      self.dump(subscriptExpression.closeSquareBracketToken)
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

  func dump(_ ifStatement: IfStatement) {
    writeNode("IfStatement") {
      self.dump(ifStatement.ifToken)
      self.dump(ifStatement.condition)

      for statement in ifStatement.body {
        self.dump(statement)
      }

      for statement in ifStatement.elseBody {
        self.dump(statement)
      }
    }
  }

  func dump(_ token: Token) {
    writeLine("token: \(token.kind.description)")
  }
}
