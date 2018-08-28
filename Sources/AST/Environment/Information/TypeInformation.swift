//
//  TypeInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// A list of properties and functions declared in a type.
public struct TypeInformation {
  var orderedProperties = [String]()
  var properties = [String: PropertyInformation]()
  var functions = [String: [FunctionInformation]]()
  var initializers = [SpecialInformation]()
  var fallbacks = [SpecialInformation]()
  var publicInitializer: SpecialDeclaration? = nil
  var publicFallback: SpecialDeclaration? = nil
}

