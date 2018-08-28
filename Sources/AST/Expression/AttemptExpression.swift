//
//  AttemptExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 28/08/2018.
//
import Source
import Lexer

public struct AttemptExpression: ASTNode {
   public var tryToken: Token
   public var kind: Kind
   public var functionCall: FunctionCall

   public var isSoft: Bool {
     return kind == .soft
   }

   public init(token: Token, sort: Token, functionCall: FunctionCall) {
     self.tryToken = token
     self.kind = sort.kind == .punctuation(.bang) ? .hard : .soft
     self.functionCall = functionCall
   }

   public enum Kind: String {
     case hard = "!"
     case soft = "?"
   }

  // MARK: - ASTNode
  public var description: String {
    return "\(tryToken)\(kind)\(functionCall)"
  }
  public var sourceLocation: SourceLocation {
    return tryToken.sourceLocation
  }
 }
