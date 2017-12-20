//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public class Parser {
   var tokens: [Token]

   public init(tokens: [Token]) {
      self.tokens = tokens
   }

   public func parse() throws -> TopLevelModule {
      return try parseTopLevelModule()
   }

   func parseTopLevelModule() throws -> TopLevelModule {
      let contractDeclaration = try parseContractDeclaration()
      let contractBehaviourDeclarations = try parseContractBehaviorDeclarations()
      return TopLevelModule(contractDeclaration: contractDeclaration, contractBehaviorDeclarations: contractBehaviourDeclarations)
   }

   func parseIdentifier() throws -> Identifier {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }
      tokens.removeFirst()
      return Identifier(name: name)
   }

   func parseTypeAnnotation() throws -> TypeAnnotation {
      try consume(.punctuation(.colon))
      let type = try parseType()
      return TypeAnnotation(type: type)
   }

   func parseType() throws -> Type {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }

      tokens.removeFirst()

      return Type(name: name)
   }

   func consume(_ token: Token) throws {
      guard let first = tokens.first, first == token else {
         throw ParserError.expectedToken(token)
      }
      tokens.removeFirst()
   }
}

extension Parser {
   func parseContractDeclaration() throws -> ContractDeclaration {
      try consume(.contract)
      let identifier = try parseIdentifier()
      try consume(.punctuation(.openBrace))
      let variableDeclarations = try parseVariableDeclarations()
      try consume(.punctuation(.closeBrace))

      return ContractDeclaration(identifier: identifier, variableDeclarations: variableDeclarations)
   }

   func parseVariableDeclarations() throws -> [VariableDeclaration] {
      var variableDeclarations = [VariableDeclaration]()

      while true {
         guard (try? consume(.var)) != nil else { break }
         let name = try parseIdentifier()
         let typeAnnotation = try parseTypeAnnotation()
         variableDeclarations.append(VariableDeclaration(name: name, type: typeAnnotation.type))
      }

      return variableDeclarations
   }
}

extension Parser {
   func parseContractBehaviorDeclarations() throws -> [ContractBehaviorDeclaration] {
      var contractBehaviorDeclarations = [ContractBehaviorDeclaration]()

      while let contractIdentifier = try? parseIdentifier() {
         try consume(.punctuation(.doubleColon))
         let callerCapabilities = try parseCallerCapabilityGroup()
         let functionDeclarations = try parseFunctionDeclarations()
         let contractBehaviorDeclaration = ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities, functionDeclarations: functionDeclarations)
         contractBehaviorDeclarations.append(contractBehaviorDeclaration)
      }

      return contractBehaviorDeclarations
   }

   func parseCallerCapabilityGroup() throws -> [CallerCapability] {
      try consume(.punctuation(.openBracket))
      let callerCapabilities = try parseCallerCapabilityList()
      try consume(.punctuation(.closeBracket))

      return callerCapabilities
   }

   func parseCallerCapabilityList() throws -> [CallerCapability] {
      var callerCapabilities = [CallerCapability]()
      repeat {
         let identifier = try parseIdentifier()
         callerCapabilities.append(CallerCapability(name: identifier.name))
      } while (try? consume(.punctuation(.comma))) != nil

      return callerCapabilities
   }

   func parseFunctionDeclarations() throws -> [FunctionDeclaration] {
      var functionDeclarations = [FunctionDeclaration]()

      while true {
         guard let modifiers = try? parseFunctionHead() else { break }
         let identifier = try parseIdentifier()
         let parameters = try parseParameters()
         let resultType = try? parseResult()
         let body = try parseFunctionBody()

         let functionDeclaration = FunctionDeclaration(modifiers: modifiers, identifier: identifier, parameters: parameters, resultType: resultType, body: body)
         functionDeclarations.append(functionDeclaration)
      }

      return functionDeclarations
   }

   func parseFunctionHead() throws -> [Token] {
      var modifiers = [Token]()

      while true {
         if (try? consume(.public)) != nil {
            modifiers.append(.public)
         } else if (try? consume(.mutating)) != nil {
            modifiers.append(.mutating)
         } else {
            break
         }
      }

      try consume(.func)
      return modifiers
   }

   func parseParameters() throws -> [Identifier] {
      try consume(.punctuation(.openBracket))
      var parameters = [Identifier]()

      repeat {
         let parameter = try parseIdentifier()
         parameters.append(parameter)
      } while (try? consume(.punctuation(.comma))) != nil

      try consume(.punctuation(.closeBracket))
      return parameters
   }

   func parseResult() throws -> Type {
      try consume(.punctuation(.arrow))
      let identifier = try parseIdentifier()
      return Type(name: identifier.name)
   }

   func parseFunctionBody() throws -> [Statement] {
      try consume(.punctuation(.openBrace))
      let statements = try parseStatements()
      try consume(.punctuation(.closeBrace))
      return statements
   }

   func parseStatements() throws -> [Statement] {
      var statements = [Statement]()

      while true {
         if let expression = try? parseExpression() {
            statements.append(expression)
         } else if let returnStatement = try? parseReturnStatement() {
            statements.append(returnStatement)
         } else {
            break
         }
      }

      return statements
   }

   func parseExpression() throws -> Expression {
      let primaryExpression = try parsePrimaryExpression()
      return Expression()
   }

   func parsePrimaryExpression() throws -> PrimaryExpression {
      if let identifier = try? parseIdentifier() {
         return identifier
      }

      return try parseMemberExpression()
   }

   func parseMemberExpression() throws -> MemberExpression {
      return MemberExpression(members: []) // TODO
   }

   func parseReturnStatement() throws -> ReturnStatement {
      try consume(.return)
      let expression = try parseExpression()
      return ReturnStatement(expression: expression)
   }
}

enum ParserError: Error {
   case expectedToken(Token)
}

public struct TopLevelModule {
   var contractDeclaration: ContractDeclaration
   var contractBehaviorDeclarations: [ContractBehaviorDeclaration]
}

struct ContractDeclaration {
   var identifier: Identifier
   var variableDeclarations: [VariableDeclaration]
}

struct ContractBehaviorDeclaration {
   var contractIdentifier: Identifier
   var callerCapabilities: [CallerCapability]
   var functionDeclarations: [FunctionDeclaration]
}

struct VariableDeclaration {
   var name: Identifier
   var type: Type
}

struct FunctionDeclaration {
   var modifiers: [Token]
   var identifier: Identifier
   var parameters: [Identifier]
   var resultType: Type?

   var body: [Statement]
}

struct TypeAnnotation {
   var type: Type
}

struct Identifier: PrimaryExpression {
   var name: String
}

struct Type {
   var name: String
}

struct CallerCapability {
   var name: String
}

protocol Statement {

}

struct Expression: Statement {

}

protocol PrimaryExpression {

}

struct MemberExpression: PrimaryExpression {
   var members: [Identifier]
}

struct ReturnStatement: Statement {
   var expression: Expression
}
