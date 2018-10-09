//
//  SemanticAnalyzer+Components.swift
//  SemanticAnalyzer
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Foundation
import AST
import Lexer
import Diagnostic

extension SemanticAnalyzer {
  /// The set of characters for identifiers which can only be used in the stdlib.
  var stdlibReservedCharacters: CharacterSet {
    return CharacterSet(charactersIn: "$")
  }

  var identifierReservedCharacters: CharacterSet {
    return CharacterSet(charactersIn: "@")
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    let environment = passContext.environment!
    var identifier = identifier
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    // Disallow identifiers from containing special characters.
    if let char =
      identifier.name.first(where: { return identifierReservedCharacters.contains($0.unicodeScalars.first!) }) {
      diagnostics.append(.invalidCharacter(identifier, character: char))
    }

    // Only allow stdlib files to include special characters, such as '$'.
    if !identifier.sourceLocation.isFromStdlib,
      let char = identifier.name.first(where: { return stdlibReservedCharacters.contains($0.unicodeScalars.first!) }) {
      diagnostics.append(.invalidCharacter(identifier, character: char))
    }

    let inFunctionDeclaration = passContext.functionDeclarationContext != nil
    let inInitializerDeclaration = passContext.specialDeclarationContext != nil
    let inFunctionOrInitializer = inFunctionDeclaration || inInitializerDeclaration

    if passContext.isPropertyDefaultAssignment, !environment.isStructDeclared(identifier.name) {
      if environment.isPropertyDefined(identifier.name, enclosingType: passContext.enclosingTypeIdentifier!.name) {
        diagnostics.append(.statePropertyUsedWithinPropertyInitializer(identifier))
      } else {
        diagnostics.append(.useOfUndeclaredIdentifier(identifier))
      }
    }

    if passContext.isFunctionCall {
      // If the identifier is the name of a function call, do nothing. The function call will be matched in
      // `process(functionCall:passContext:)`.
    } else if inFunctionOrInitializer, !passContext.isInBecome, !passContext.isInEmit {
      // The identifier is used within the body of a function or an initializer

      // The identifier is used an l-value (the left-hand side of an assignment).
      let asLValue = passContext.asLValue ?? false

      if identifier.enclosingType == nil {
        // The identifier has no explicit enclosing type, such as in the expression `foo` instead of `a.foo`.

        let scopeContext = passContext.scopeContext!
        if let variableDeclaration = scopeContext.declaration(for: identifier.name) {
          if variableDeclaration.isConstant,
            !variableDeclaration.type.rawType.isInout,
            asLValue,
            !passContext.isInSubscript {
            // The variable is a constant but is attempted to be reassigned.
            diagnostics.append(.reassignmentToConstant(identifier, variableDeclaration.sourceLocation))
          }
        } else if !passContext.environment!.isEnumDeclared(identifier.name) {
          // If the variable is not declared locally and doesn't refer to an enum,
          // assign its enclosing type to the struct or contract behavior
          // declaration in which the function appears.
          identifier.enclosingType = passContext.enclosingTypeIdentifier!.name
        } else if !(passContext.isEnclosing) {
          // Checking if we are refering to 'foo' in 'a.foo'
          diagnostics.append(.invalidReference(identifier))
        }
      }

      if let enclosingType = identifier.enclosingType, enclosingType != RawType.errorType.name {
        if !passContext.environment!.isPropertyDefined(identifier.name, enclosingType: enclosingType) {
          // The property is not defined in the enclosing type.
          diagnostics.append(.useOfUndeclaredIdentifier(identifier))
          passContext.environment!.addUsedUndefinedVariable(identifier, enclosingType: enclosingType)
        } else if asLValue, !passContext.isInSubscript {

          if passContext.environment!.isPropertyConstant(identifier.name, enclosingType: enclosingType) {
            // Retrieve the source location of that property's declaration.
            let declarationSourceLocation =
              passContext.environment!.propertyDeclarationSourceLocation(identifier.name, enclosingType: enclosingType)!

            if !inInitializerDeclaration ||
              passContext.environment!.isPropertyAssignedDefaultValue(identifier.name, enclosingType: enclosingType) {
              // The state property is a constant but is attempted to be reassigned.
              diagnostics.append(.reassignmentToConstant(identifier, declarationSourceLocation))
            }
          }

          // In initializers or fallback
          if passContext.specialDeclarationContext != nil {
            // Check if the property has been marked as assigned yet.
            if let first = passContext.unassignedProperties!.index(where: {
              $0.identifier.name == identifier.name && $0.identifier.enclosingType == identifier.enclosingType
            }) {
              // Mark the property as assigned.
              passContext.unassignedProperties!.remove(at: first)
            }
          }

          if let functionDeclarationContext = passContext.functionDeclarationContext {
            // The variable is being mutated in a function.
            if !functionDeclarationContext.isMutating {
              // The function is declared non-mutating.
              diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(
                .identifier(identifier),
                functionDeclaration: functionDeclarationContext.declaration))
            }
            // Record the mutating expression in the context.
            addMutatingExpression(.identifier(identifier), passContext: &passContext)
          }
        }
      }
    } else if passContext.isInBecome {
      if let functionDeclarationContext = passContext.functionDeclarationContext {
        // The variable is being mutated in a function.
        if !functionDeclarationContext.isMutating {
          // The function is declared non-mutating.
          diagnostics.append(
            .useOfMutatingExpressionInNonMutatingFunction(.identifier(identifier),
                                                          functionDeclaration: functionDeclarationContext.declaration))
        }
        // Record the mutating expression in the context.
        addMutatingExpression(.identifier(identifier), passContext: &passContext)
      }
    }

    return ASTPassResult(element: identifier, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    var diagnostics = [Diagnostic]()

    if parameter.type.rawType.isUserDefinedType, !parameter.isInout {
      // Ensure all structs are passed by reference, for now.
      diagnostics.append(Diagnostic(severity: .error, sourceLocation: parameter.sourceLocation,
                                    message: "Structs cannot be passed by value yet, and have to be passed inout"))
    }

    return ASTPassResult(element: parameter, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(callerProtection: CallerProtection,
                      passContext: ASTPassContext) -> ASTPassResult<CallerProtection> {
    let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if !callerProtection.isAny &&
      !environment.containsCallerProtection(callerProtection,
                                            enclosingType: contractBehaviorDeclarationContext.contractIdentifier.name) {
      // The caller protection is neither `any` or a valid property in the enclosing contract.
      diagnostics.append(
        .undeclaredCallerProtection(callerProtection,
                                    contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
    }

    return ASTPassResult(element: callerProtection, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    // TODO: Check that type state exists, etc.

    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }

  public func process(conformance: Conformance, passContext: ASTPassContext) -> ASTPassResult<Conformance> {
    let environment = passContext.environment!
    let contractDeclarationContext = passContext.contractStateDeclarationContext!
    var diagnostics = [Diagnostic]()

    if !environment.isTraitDeclared(conformance.name) {
      diagnostics.append(.contractUsesUndeclaredTraits(conformance, in: contractDeclarationContext.contractIdentifier))
    }
    return ASTPassResult(element: conformance, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    var diagnostics = [Diagnostic]()
    if case .literal(let token) = literalToken.kind,
      case .address(let address) = token,
      address.count != 42 {
      diagnostics.append(.invalidAddressLiteral(literalToken))
    }
    return ASTPassResult(element: literalToken, diagnostics: diagnostics, passContext: passContext)
  }
}
