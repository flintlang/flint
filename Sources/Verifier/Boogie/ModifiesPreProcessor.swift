//
// Created by matthewross on 21/08/19.
//

import Foundation
import AST

public class GenerateCalledConstructors: ASTPass {
  public init() {}

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    guard let environment = passContext.environment,
          let enclosingType = passContext.enclosingTypeIdentifier?.name,
          let scopeContext = passContext.scopeContext else {
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    var passContext = passContext
    switch environment.matchFunctionCall(
        functionCall,
        enclosingType: enclosingType,
        typeStates: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
        callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? [],
        scopeContext: scopeContext
    ) {
    case .matchedInitializer(let information):
      guard information.declaration.isInit else {
        break
      }
      guard let type: TypeInformation = environment.types[functionCall.identifier.name] else {
        fatalError("Cannot identify type constructor is attempting to construct")
      }
      passContext.constructors += [type]
    default: break
    }
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    guard let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      fatalError("Cannot get enclosing type name")
    }
    var passContext = passContext
    let name = normaliseFunctionName(function: functionDeclaration, enclosingType: enclosingType)
    passContext.environment?.calledConstructors[name] = passContext.constructors
    passContext.constructors = []
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    guard let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      fatalError("Cannot get enclosing type name")
    }
    var passContext = passContext
    let name = normaliseFunctionName(function: specialDeclaration.asFunctionDeclaration, enclosingType: enclosingType)
    passContext.environment?.calledConstructors[name] = passContext.constructors
    passContext.constructors = []
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }
}

public class ModifiesPreProcessor: ASTPass {
  private let normaliser: IdentifierNormaliser = IdentifierNormaliser()

  public init() {}

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration
    functionDeclaration.signature.mutates += getAllConstructors(
        function: functionDeclaration,
        passContext: passContext
    ).flatMap { (constructor: TypeInformation) in
      return constructor.properties.map { $0.value.property.identifier }
    }
    functionDeclaration.signature.mutates
        = expandMutatedProperties(of: functionDeclaration.signature.mutates, passContext: passContext)
    var passContext = passContext
    passContext.constructors = []
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var specialDeclaration = specialDeclaration
    specialDeclaration.signature.mutates += getAllConstructors(
        function: specialDeclaration.asFunctionDeclaration,
        passContext: passContext
    ).flatMap { (constructor: TypeInformation) in
      return constructor.properties.map { $0.value.property.identifier }
    }
    specialDeclaration.signature.mutates
        = expandMutatedProperties(of: specialDeclaration.signature.mutates, passContext: passContext)
    var passContext = passContext
    passContext.constructors = []
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  private func getAllConstructors(function: FunctionDeclaration, passContext: ASTPassContext) -> [TypeInformation] {
    guard let environment = passContext.environment,
          let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      return []
    }
    let name = normaliseFunctionName(function: function, enclosingType: enclosingType)
    return getAllConstructors(functionName: name, environment: environment)
  }

  private func getAllConstructors(functionName: String,
                                  environment: Environment,
                                  visited: Set<String> = []) -> [TypeInformation] {
    guard !visited.contains(functionName) else {
      return environment.calledConstructors[functionName] ?? []
    }
    let visited = visited.union([functionName])
    return (environment.calledConstructors[functionName] ?? [])
        + (environment.callGraph[functionName]?.flatMap({
            getAllConstructors(functionName: $0.0,
                                 environment: environment,
                                 visited: visited)
        }) ?? [])
  }

  func expandMutatedProperties(of mutates: [Identifier],
                               passContext: ASTPassContext) -> [Identifier] {
    guard let environment = passContext.environment,
          let scopeContext = passContext.scopeContext,
          let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      fatalError("Expanding mutated properties requires local static information")
    }
    return mutates.flatMap { (identifier: Identifier) -> [Identifier] in
      let type: RawType = passContext.environment!.type(of: .identifier(identifier),
                                                        enclosingType: enclosingType,
                                                        scopeContext: scopeContext)
      return [identifier] + allMutatedProperties(of: type, environment: environment)
    }
  }

  func allMutatedProperties(of type: RawType, environment: Environment, visited: Set<RawType> = []) -> [Identifier] {
    guard !visited.contains(type) else {
      return []
    }

    var visited = visited.union([type])

    switch type {
    case .userDefinedType(let name):
      if let information: TypeInformation = environment.types[name] {
        return information.properties.values.flatMap { (information: PropertyInformation) -> [Identifier] in
          [information.property.identifier] + allMutatedProperties(of: information.rawType,
                                                                   environment: environment,
                                                                   visited: visited)
        }
      }
    case .dictionaryType(let key, let value):
      return allMutatedProperties(of: key, environment: environment, visited: visited)
          + allMutatedProperties(of: value, environment: environment, visited: visited)
    case .arrayType(let element):
      return allMutatedProperties(of: element, environment: environment, visited: visited)
    case .fixedSizeArrayType(let element, _):
      return allMutatedProperties(of: element, environment: environment, visited: visited)
    case .inoutType(let type):
      return allMutatedProperties(of: type, environment: environment, visited: visited)
    default: break
    }
    return []
  }

  /*private func getCalled(function: FunctionDeclaration,
                          passContext: ASTPassContext) -> [FunctionDeclaration] {
    guard let environment = passContext.environment,
          let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      return []
    }
    let name = normaliseFunctionName(function: function.name, enclosingType: enclosingType)
    return environment.callGraph[name]
  }*/
}

private func normaliseFunctionName(function: FunctionDeclaration,
                                   enclosingType: String) -> String {
  return normaliseFunctionName(functionName: function.name,
                               parameterTypes: function.signature.parameters.rawTypes,
                               enclosingType: enclosingType)
}

private func normaliseFunctionName(functionName: String,
                                   parameterTypes: [RawType],
                                   enclosingType: String) -> String {
  return IdentifierNormaliser()
      .translateGlobalIdentifierName(functionName + parameterTypes.reduce("", { $0 + $1.name }),
                                     tld: enclosingType)
}

private struct ConstructorsContextEntry: PassContextEntry {
  typealias Value = [TypeInformation]  // Should be set if TypeInformation were hashable
}

extension ASTPassContext {
  public var constructors: [TypeInformation] {
    get { return self[ConstructorsContextEntry.self] ?? [] }
    set { self[ConstructorsContextEntry.self] = newValue }
  }
}
