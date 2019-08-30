//
// Created by matthewross on 28/08/19.
//

import Foundation
import AST
import Source
import Lexer

public struct MoveScopeProcessor: ASTPass {

  public init() {}

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var passContext = passContext
    passContext.scopeStack?.push(name: "if\(ifStatement.sourceLocation.line)")
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var passContext = passContext
    guard let topName: String = passContext.scopeStack?.top?.name,
          topName == "if\(ifStatement.sourceLocation.line)" else {
      return ASTPassResult(element: ifStatement,
                           diagnostics: [.init(severity: .error,
                                               sourceLocation: ifStatement.sourceLocation,
                                               message: "Unbalanced if statement whilst deducing scope prefixes")],
                           passContext: passContext)
    }
    passContext.scopeStack?.pop()
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    var identifier = identifier
    if identifier.enclosingType == nil,
       let scopeStack = passContext.scopeStack {
      identifier = scopeStack.mangle(identifier: identifier)
    }
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    passContext.scopeStack?.addToTop(identifier: variableDeclaration.identifier)
    var updatedPassContext = passContext
    if let top = passContext.scopeStack?.top,
       !top.name.isEmpty {
      updatedPassContext.blockContext?.scopeContext.localVariables = mangleLocalVariable(
          variables: passContext.blockContext?.scopeContext.localVariables ?? [],
          name: variableDeclaration.identifier.name,
          passContext: passContext
      )
      updatedPassContext.functionDeclarationContext?.innerDeclarations = mangleLocalVariable(
        variables: passContext.functionDeclarationContext?.innerDeclarations ?? [],
        name: variableDeclaration.identifier.name,
        passContext: passContext
      )
      updatedPassContext.specialDeclarationContext?.innerDeclarations = mangleLocalVariable(
          variables: passContext.functionDeclarationContext?.innerDeclarations ?? [],
          name: variableDeclaration.identifier.name,
          passContext: passContext
      )
    }
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: updatedPassContext)
  }

  private func mangleLocalVariable(variables: [VariableDeclaration],
                                   name: String,
                                   passContext: ASTPassContext) -> [VariableDeclaration] {
    return variables.map { (local: VariableDeclaration) -> VariableDeclaration in
      var local = local
      if local.identifier.name == name {
        local.identifier = passContext.scopeStack!.mangle(identifier: local.identifier)
      }
      return local
    }
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var passContext = passContext
    passContext.scopeStack = ScopeStack(
        levels: [StackLevel(name: "",
                            prefix: "",
                            variables: functionDeclaration.signature.parameters.map({ $0.identifier }))]
    )
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var passContext = passContext
    passContext.scopeStack = nil
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var passContext = passContext
    passContext.scopeStack = ScopeStack(
        levels: [StackLevel(name: "",
                            prefix: "",
                            variables: specialDeclaration.signature.parameters.map({ $0.identifier }))]
    )
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var passContext = passContext
    passContext.scopeStack = nil
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }
}

struct StackLevel {
  var name: String
  var prefix: String
  var variables: [Identifier]

  public init(name: String, prefix: String, variables: [Identifier] = []) {
    self.name = name
    self.variables = variables
    self.prefix = prefix
  }

  public mutating func add(_ element: Identifier) {
    variables.append(element)
  }

  public func contains(name: String) -> Bool {
    return variables.contains(where: { $0.name == name })
  }
}

struct ScopeStack {
  public private(set) var levels: [StackLevel] = []

  public var top: StackLevel? {
    get {
      return levels.last
    }
    set {
      levels[levels.count - 1] = newValue!
    }
  }

  public mutating func freshIdentifier(sourceLocation: SourceLocation,
                                       scopeContext: inout ScopeContext) -> Identifier {
    let identifier = scopeContext.freshIdentifier(sourceLocation: sourceLocation)
    addToTop(identifier: identifier)
    return mangle(identifier: identifier)
  }

  public func mangle(identifier: Identifier) -> Identifier {
    guard identifier.enclosingType == nil else {
      return identifier
    }
    return Identifier(name: mangle(name: identifier.name),
                      sourceLocation: identifier.sourceLocation,
                      enclosingType: identifier.enclosingType)
  }

  public func mangle(name: String) -> String {
    if let level: StackLevel = levels.last(where: { $0.contains(name: name) }) {
      let count: Int = level.variables.filter { $0.name == name }.count
      if count > 1 {
        return "\(level.prefix)_\(count)_\(name)"
      }
      return level.prefix + name
    }
    return name
  }

  public var prefix: String {
    return levels.reduce("") { $0 + $1.name }
  }

  public mutating func push(name: String) {
    push(StackLevel(name: name, prefix: prefix + name))
  }

  public mutating func addToTop(identifier: Identifier) {
    let variables = top?.variables ?? []
    top?.variables = variables + [identifier]
  }

  public mutating func push(_ stackLevel: StackLevel) {
    levels.append(stackLevel)
  }

  public mutating func pop() {
    levels.removeLast()
  }
}

extension ASTPassContext {
  var scopeStack: ScopeStack? {
    get { return self[ScopeStackContextEntry.self] }
    set { self[ScopeStackContextEntry.self] = newValue }
  }
}

struct ScopeStackContextEntry: PassContextEntry {
  typealias Value = ScopeStack
}
