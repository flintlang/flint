//
//  CallableInformation.swift
//  AST
//
//  Created by Harkness, Alexander on 2018-09-03
//

// Information about a callable unit, either a normal function or initializer/fallback function.
public enum CallableInformation {
  case functionInformation(FunctionInformation)
  case specialInformation(SpecialInformation)

  var parameterTypes: [RawType] {
    switch self {
    case .functionInformation(let functionInformation):
      return functionInformation.parameterTypes
    case .specialInformation(let specialInformation):
      return specialInformation.parameterTypes
    }
  }
}
