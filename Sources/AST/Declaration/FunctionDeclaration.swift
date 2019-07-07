//
//  FunctionDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer
import ABI

/// The declaration of a function.
public struct FunctionDeclaration: ASTNode {
  public var signature: FunctionSignatureDeclaration
  public var body: [Statement]
  public var closeBraceToken: Token
  public var isExternal: Bool

  public var mangledIdentifier: String?
  public var externalSignatureHash: [UInt8]?

  // Contextual information for the scope defined by the function.
  public var scopeContext: ScopeContext?

  public init(signature: FunctionSignatureDeclaration,
              body: [Statement],
              closeBraceToken: Token,
              scopeContext: ScopeContext? = nil,
              isExternal: Bool = false) {
    self.signature = signature
    self.body = body
    self.closeBraceToken = closeBraceToken
    self.scopeContext = scopeContext
    self.isExternal = isExternal

    if isExternal {
      let args = signature.parameters.map { $0.type.rawType.name }.joined(separator: ",")

      let name = signature.identifier.name
      self.externalSignatureHash = ABI.soliditySelectorRaw(of: "\(name)(\(args))")
    }
  }

  public var isMutating: Bool {
    return signature.mutates.count > 0
  }

  public var mutates: [Identifier] {
    return signature.mutates
  }

  public var isPayable: Bool {
    return signature.attributes.contains { $0.kind == .payable }
  }

  public var isVoid: Bool {
    return signature.resultType == nil || signature.resultType?.rawType == .basicType(.void)
  }

  /// The first parameter which is both `implicit` and has a currency type.
  public var firstPayableValueParameter: Parameter? {
    return signature.parameters.first { $0.isPayableValueParameter }
  }

  /// The non-implicit parameters of the function.
  public var explicitParameters: [Parameter] {
    return signature.parameters.filter { !$0.isImplicit }
  }

  public var isPublic: Bool {
    return signature.hasModifier(kind: .public)
  }

  public var identifier: Identifier {
    return signature.identifier
  }

  public var name: String {
    return identifier.name
  }

  // MARK: - ASTNode
  public var description: String {
    let bodyText = body.map({ $0.description }).joined(separator: "\n")
    return "\(signature) {\(bodyText)}"
  }

  public var sourceLocation: SourceLocation {
    return signature.sourceLocation
  }
}
