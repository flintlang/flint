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

  public func hasHyperParameter(parameterName: String) -> Bool {
    return getHyperParameter(parameterName: parameterName) != nil
  }

  public func getHyperParameter(parameterName: String) -> FunctionArgument? {
    for parameter in hyperParameters {
      if let identifier = parameter.identifier {
        if identifier.name == parameterName {
          return parameter
        }
      }
    }

    return nil
  }
}
