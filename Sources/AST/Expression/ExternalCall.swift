//
//  ExternalCall.swift
//  AST
//
//  Created by Catalin Craciun on 10/11/2018.
//
import Source
import Lexer

/// A call to an external function
public struct ExternalCall: ASTNode {
  public enum Mode {
    case normal, returnsGracefullyOptional, isForced
  }

  public var hyperParameters: [FunctionArgument]
  public var functionCall: BinaryExpression
  public var mode: Mode

  public init(hyperParameters: [FunctionArgument],
              functionCall: BinaryExpression,
              mode: Mode) {
    self.hyperParameters = hyperParameters
    self.functionCall = functionCall
    self.mode = mode
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return functionCall.sourceLocation
  }

  public var description: String {
    let configurationText = hyperParameters.map({ $0.description }).joined(separator: ", ")
    return "call(\(configurationText)) - " + "\(functionCall.description))"
  }
}
