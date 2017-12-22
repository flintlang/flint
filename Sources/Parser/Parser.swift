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

   func consume(_ token: Token) throws {
      guard let first = tokens.first, first == token else {
         throw ParserError.expectedToken(token)
      }
      tokens.removeFirst()
   }
}

extension Parser {
   func parseTopLevelModule() throws -> TopLevelModule {
      let topLevelDeclarations = try parseTopLevelDeclarations()
      return TopLevelModule(declarations: topLevelDeclarations)
   }

   func parseTopLevelDeclarations() throws -> [TopLevelDeclaration] {
      var declarations = [TopLevelDeclaration]()

      while true {
         if let contractDeclaration = try? parseContractDeclaration() {
            declarations.append(.contractDeclaration(contractDeclaration))
         } else if let contractBehaviorDeclaration = try? parseContractBehaviorDeclaration() {
            declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
         } else {
            break
         }
      }

      return declarations
   }
}

extension Parser {
   func parseIdentifier() throws -> Identifier {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }
      tokens.removeFirst()
      return Identifier(name: name)
   }

   func parseType() throws -> Type {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }

      tokens.removeFirst()
      return Type(name: name)
   }

   func parseTypeAnnotation() throws -> TypeAnnotation {
      try consume(.punctuation(.colon))
      let type = try parseType()
      return TypeAnnotation(type: type)
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

      while (try? consume(.var)) != nil {
         let name = try parseIdentifier()
         let typeAnnotation = try parseTypeAnnotation()
         variableDeclarations.append(VariableDeclaration(identifier: name, type: typeAnnotation.type))
      }

      return variableDeclarations
   }
}

extension Parser {
   func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
      let contractIdentifier = try parseIdentifier()
      try consume(.punctuation(.doubleColon))
      let callerCapabilities = try parseCallerCapabilityGroup()
      try consume(.punctuation(.openBrace))
      let functionDeclarations = try parseFunctionDeclarations()
      try consume(.punctuation(.closeBrace))

      return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities, functionDeclarations: functionDeclarations)
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

      while let modifiers = try? parseFunctionHead() {
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

   func parseParameters() throws -> [Parameter] {
      try consume(.punctuation(.openBracket))
      var parameters = [Parameter]()

      if (try? consume(.punctuation(.closeBracket))) != nil {
         return []
      }

      repeat {
         let identifier = try parseIdentifier()
         let typeAnnotation = try parseTypeAnnotation()
         parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type))
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
            statements.append(.expression(expression))
         } else if let returnStatement = try? parseReturnStatement() {
            statements.append(.returnStatement(returnStatement))
         } else {
            break
         }
      }

      return statements
   }

   func parseExpression() throws -> Expression {
      let expression = try parseExpression(upTo: .punctuation(.semicolon))
      try consume(.punctuation(.semicolon))
      return expression
   }

   private func parseExpression(upTo limitToken: Token) throws -> Expression {
      var expressionTokens = tokens.prefix { $0 != limitToken }

      var binaryExpression: BinaryExpression? = nil
      for op in Token.BinaryOperator.allByIncreasingPrecedence where expressionTokens.contains(.binaryOperator(op)) {
         let lhs = try parseExpression(upTo: .binaryOperator(op))
         try consume(.binaryOperator(op))
         expressionTokens = tokens.prefix { $0 != limitToken }
         let rhs = try parseExpression(upTo: tokens[tokens.index(of: expressionTokens.last!)! + 1])
         binaryExpression = BinaryExpression(lhs: lhs, op: op, rhs: rhs)
         break
      }

      guard let binExp = binaryExpression else {
         return .identifier(try parseIdentifier())
      }

      return .binaryExpression(binExp)
   }

   func parseReturnStatement() throws -> ReturnStatement {
      try consume(.return)
      let expression = try parseExpression()
      return ReturnStatement(expression: expression)
   }
}

enum ParserError: Error {
   case expectedToken(Token)
   case expectedOneOfTokens([Token])
}
