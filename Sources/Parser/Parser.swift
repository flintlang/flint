//
//  Parser.swift
//  Parser
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import Foundation
import AST
import Source
import Lexer
import Diagnostic

/// The parser, which creates an Abstract Syntax Tree (AST) from a list of tokens.
public class Parser {
  /// The list of tokens from which to create an AST.
  var tokens: [Token]

  /// The index of the current token being processed.
  var currentIndex: Int

  /// The current token being processed.
  var currentToken: Token? {
    return currentIndex < tokens.count ? tokens[currentIndex] : nil
  }

  var latestSource: SourceLocation {
    return currentIndex >= tokens.count ? tokens[tokens.count - 1].sourceLocation : tokens[currentIndex].sourceLocation
  }

  /// Semantic information about the source program.
  var environment = Environment()

  // Diagnostics
  var diagnostics = [Diagnostic]()

  public init(tokens: [Token]) {
    self.tokens = tokens
    self.currentIndex = tokens.startIndex
  }

  /// Parses the token list.
  ///
  /// - Returns:  A triple containing the top-level Flint module (the root of the AST), the generated environment,
  ///             and the list of diagnostics emitted.
  public func parse() -> (TopLevelModule?, Environment, [Diagnostic]) {
    let topLevelModule = try? parseTopLevelModule()
    setupEnvironment(using: topLevelModule)
    return (topLevelModule, environment, diagnostics)
  }

  private func setupEnvironment(using topLevelModule: TopLevelModule?) {
    if let ast = topLevelModule {
      ast.declarations.forEach { (tld) in
        switch tld {
        case .contractDeclaration(let contract):
          environment.addContract(contract)
          // TODO: Add conformances here
          if contract.isStateful {
            environment.addEnum(contract.stateEnum)
          }
          for member in contract.members {
            if case .eventDeclaration(let eventDeclaration) = member {
              environment.addEvent(eventDeclaration, enclosingType: contract.identifier.name)
            }
          }
        case .contractBehaviorDeclaration(let behaviour):
          let contractIdentifier = behaviour.contractIdentifier.name
          for member in behaviour.members {
            switch member {
            case .functionDeclaration(let functionDeclaration):
              // Record all the function declarations.
              environment.addFunction(functionDeclaration, enclosingType: contractIdentifier, states: behaviour.states, callerCapabilities: behaviour.callerCapabilities)
            case .specialDeclaration(let specialDeclaration):
              if specialDeclaration.isInit {
                environment.addInitializer(specialDeclaration, enclosingType: contractIdentifier)
                if specialDeclaration.isPublic, environment.publicInitializer(forContract: contractIdentifier) == nil {
                  // Record the public initializer, we will need to know if one of was declared during semantic analysis of the
                  // contract's state properties.
                  environment.setPublicInitializer(specialDeclaration, forContract: contractIdentifier)
                }
              } else if specialDeclaration.isFallback {
                environment.addFallback(specialDeclaration, enclosingType: contractIdentifier)
              }
            }
          }
        case .structDeclaration(let structDeclaration):
          environment.addStruct(structDeclaration)
          // TODO: Add conformances here 

        case .enumDeclaration(let enumDeclaration):
          environment.addEnum(enumDeclaration)
        }
      }
    }
  }
}

/// An error during parsing.
///
/// - expectedToken: The current token did not match the token we expected.
enum ParserError: Error {
  case emit(Diagnostic)
}
