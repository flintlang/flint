// Triggers.swift
// Handles the insertion of shadow expressions, operating on metavariables
// Which the verifier uses to prove extra properties about the contracts
// Eg, totalValue_Wei == receivedValue_Wei - sentValue_Wei

import AST
import Source
import Foundation

struct Trigger {
  public let globalMetaVariableDeclaration: [BVariableDeclaration]
  public let invariants: [BIRInvariant]

  private let parameterTriggers: [Rule<Parameter>]
  private let functionCallTriggers: [Rule<FunctionCall>]
  private let functionDeclarationTriggers: [Rule<FunctionDeclaration>]
  private let binaryExpressionTriggers: [Rule<BinaryExpression>]

  public func lookup(_ parameter: Parameter, _ context: Context, extra: ExtraType = [:]) -> ([BStatement], [BStatement]) {
    return unzip(parameterTriggers.filter({ $0.condition(parameter, context, extra) })
      .map({ $0.rule(parameter, context, extra) }))
  }

  public func lookup(_ functionDeclaration: FunctionDeclaration, _ context: Context, extra: ExtraType = [:]) -> ([BStatement], [BStatement]) {
  return unzip(functionDeclarationTriggers.filter({ $0.condition(functionDeclaration, context, extra) })
      .map({ $0.rule(functionDeclaration, context, extra) }))
  }

  public func lookup(_ functionCall: FunctionCall, _ context: Context, extra: ExtraType = [:]) -> ([BStatement], [BStatement]) {
    return unzip(functionCallTriggers.filter({ $0.condition(functionCall, context, extra) })
      .map({ $0.rule(functionCall, context, extra) }))
  }

  public func lookup(_ binaryExpression: BinaryExpression, _ context: Context, extra: ExtraType = [:]) -> ([BStatement], [BStatement]) {
    return unzip(binaryExpressionTriggers.filter({ $0.condition(binaryExpression, context, extra) })
      .map({ $0.rule(binaryExpression, context, extra) }))
  }

  public func mutates(_ parameter: Parameter, _ context: Context, extra: ExtraType = [:]) -> [String] {
    return parameterTriggers.filter({ $0.condition(parameter, context, extra) })
      .flatMap({ $0.mutates })
  }

  public func mutates(_ functionDeclaration: FunctionDeclaration, _ context: Context, extra: ExtraType = [:]) -> [String] {
    return functionDeclarationTriggers.filter({ $0.condition(functionDeclaration, context, extra) })
      .flatMap({ $0.mutates })
  }

  public func mutates(_ functionCall: FunctionCall, _ context: Context, extra: ExtraType = [:]) -> [String] {
    return functionCallTriggers.filter({ $0.condition(functionCall, context, extra) })
      .flatMap({ $0.mutates })
  }

  public func mutates(_ binaryExpression: BinaryExpression, _ context: Context, extra: ExtraType = [:]) -> [String] {
    return binaryExpressionTriggers.filter({ $0.condition(binaryExpression, context, extra) })
      .flatMap({ $0.mutates })
  }

  private static func registerParameterTriggers() -> [Rule<Parameter>] {
    var triggers = [Rule<Parameter>]()
    triggers.append(TriggerRule.weiCreationImplicit())
    return triggers
  }

  private static func registerFunctionCallTriggers() -> [Rule<FunctionCall>] {
    let triggers = [Rule<FunctionCall>]()
    return triggers
  }

  private static func registerFunctionDeclarationTriggers() -> [Rule<FunctionDeclaration>] {
    var triggers = [Rule<FunctionDeclaration>]()
    triggers.append(TriggerRule.weiCreationUnsafeInit())
    triggers.append(TriggerRule.weiSetupInvariantOnInit())
    return triggers
  }

  private static func registerBinaryExpressionTriggers() -> [Rule<BinaryExpression>] {
    var triggers = [Rule<BinaryExpression>]()
    triggers.append(TriggerRule.weiDirectAssignment())
    return triggers
  }

  private static func registerInvariants() -> [BIRInvariant] {
    var invariants = [BIRInvariant]()
    // Wei Accounting
    // TODO: Pass in SourceLocation - for Wei - determine the syntax needed for this
    let source = SourceLocation(line: 42, column: 42, length: 3, file: URL(string: "stdlib/Asset.flint")!, isFromStdlib: true)
    invariants.append(BIRInvariant(expression: .equals(.identifier("totalValue_Wei"),
                                                           .subtract(.identifier("receivedValue_Wei"),
                                                                     .identifier("sentValue_Wei"))),
                                       ti: TranslationInformation(sourceLocation: source)))
    return invariants
  }

  private static func registerMetaVarableDeclarations() -> [BVariableDeclaration] {
    var declarations = [BVariableDeclaration]()
    // Wei Accounting
    declarations.append(BVariableDeclaration(name: "totalValue_Wei",
                                             rawName: "totalValue_Wei",
                                             type: .int))
    declarations.append(BVariableDeclaration(name: "receivedValue_Wei",
                                             rawName: "receivedValue_Wei",
                                             type: .int))
    declarations.append(BVariableDeclaration(name: "sentValue_Wei",
                                             rawName: "sentValue_Wei",
                                             type: .int))
    return declarations
  }

  public init() {
    self.invariants = Trigger.registerInvariants()
    self.globalMetaVariableDeclaration = Trigger.registerMetaVarableDeclarations()

    self.parameterTriggers = Trigger.registerParameterTriggers()
    self.functionDeclarationTriggers = Trigger.registerFunctionDeclarationTriggers()
    self.functionCallTriggers = Trigger.registerFunctionCallTriggers()
    self.binaryExpressionTriggers = Trigger.registerBinaryExpressionTriggers()
  }
}

typealias ExtraType = [String: Any]

struct Context {
  let environment: Environment
  let enclosingType: String
  let scopeContext: ScopeContext
}

struct Rule<X> {
  let condition: (X, Context, ExtraType) -> Bool
  let rule: (X, Context, ExtraType) -> ([BStatement], [BStatement])
  let mutates: [String]
}

struct TriggerRule {
}

// Given sequence of 2-tuples, return two arrays
func unzip<T, U>(_ sequence: [([T], [U])]) -> ([T], [U]) {
  var t = [T]()
  var u = [U]()
  for (a, b) in sequence {
    t += a
    u += b
  }
  return (t, u)
}
