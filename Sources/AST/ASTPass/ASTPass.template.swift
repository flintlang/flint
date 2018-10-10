// swiftlint:disable all
//
//  ASTPass.swift
//  AST
//
//  Created by Franklin Schrans on 1/11/18.
//
import Diagnostic
import Lexer

/// A pass over an AST.
///
/// The class `ASTVisitor` is used to visit an AST using a given `ASTPass`. The appropriate `process` function will be
/// called when visiting a node, and `postProcess` will be called after visiting the children of that node.
public protocol ASTPass {
  {# Modules #}
  {%- set nodes = [
    "TopLevelModule"
  ] -%}
  
  {# Declarations #}
  {%- set nodes = nodes.concat([
    "TopLevelDeclaration",
    "ContractDeclaration",
    "StructDeclaration",
    "EnumDeclaration",
    "TraitDeclaration",
    "ContractBehaviorDeclaration"
  ]) -%}

  {# Members #}
  {%- set nodes = nodes.concat([
    "ContractMember",
    "StructMember",
    "EnumMember",
    "TraitMember",
    "ContractBehaviorMember"
  ]) -%}
  
  {# Statements #}
  {%- set nodes = nodes.concat([
    "Statement",
    "ReturnStatement",
    "BecomeStatement",
    "EmitStatement",
    "IfStatement",
    "ForStatement"
  ]) -%}
  
  {# Declarations #}
  {%- set nodes = nodes.concat([
    "VariableDeclaration",
    "FunctionDeclaration",
    "FunctionSignatureDeclaration",
    "SpecialDeclaration",
    "SpecialSignatureDeclaration",
    "EventDeclaration"
  ]) -%}
  
  {# Expression #}
  {%- set nodes = nodes.concat([
    "Expression",
    "InoutExpression",
    "BinaryExpression",
    "FunctionCall",
    "ArrayLiteral",
    "DictionaryLiteral",
    "RangeExpression",
    "SubscriptExpression",
    "AttemptExpression"
  ]) -%}

  {# Components #}
  {%- set nodes = nodes.concat([
    "Attribute",
    "Parameter",
    "TypeAnnotation",
    "Identifier",
    "Type",
    "Token",
    "CallerProtection",
    "TypeState",
    "Conformance",
    "FunctionArgument"
  ]) -%}

  {%- for node in nodes %}
  func process({{ node | camelCase }}: {{ node }}, passContext: ASTPassContext) -> ASTPassResult<{{ node }}>
  func postProcess({{ node | camelCase }}: {{ node }}, passContext: ASTPassContext) -> ASTPassResult<{{ node }}>
  {% endfor %}
}

extension ASTPass {
  {%- for node in nodes %}
  public func process({{ node | camelCase }}: {{ node }}, passContext: ASTPassContext) -> ASTPassResult<{{ node }}> {
    return ASTPassResult(element: {{ node | camelCase }}, diagnostics: [], passContext: passContext)
  }

  public func postProcess({{ node | camelCase }}: {{ node }}, passContext: ASTPassContext) -> ASTPassResult<{{ node }}> {
    return ASTPassResult(element: {{ node | camelCase }}, diagnostics: [], passContext: passContext)
  }
  {% endfor %}
}
// swiftlint:enable all
