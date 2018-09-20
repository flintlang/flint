//
//  IRContract.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

/// Generates code for a contract.
struct IRContract {

  static var stateVariablePrefix = "flintState$"

  var contractDeclaration: ContractDeclaration
  var contractBehaviorDeclarations: [ContractBehaviorDeclaration]
  var structDeclarations: [StructDeclaration]
  var environment: Environment

  init(contractDeclaration: ContractDeclaration, contractBehaviorDeclarations: [ContractBehaviorDeclaration], structDeclarations: [StructDeclaration], environment: Environment) {
    self.contractDeclaration = contractDeclaration
    self.contractBehaviorDeclarations = contractBehaviorDeclarations
    self.structDeclarations = structDeclarations
    self.environment = environment
  }


  func rendered() -> String {
    // Generate code for each function in the contract.
    let functions = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> IRFunction? in
        guard case .functionDeclaration(let functionDeclaration) = member else {
          return nil
        }
        return IRFunction(functionDeclaration: functionDeclaration, typeIdentifier: contractDeclaration.identifier, typeStates: contractBehaviorDeclaration.states, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, environment: environment)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    // Generate wrapper functions
    let wrapperCode = functions.filter({ !$0.containsAnyCaller })
     .map({ IRWrapperFunction(function: $0).rendered(enclosingType: contractDeclaration.identifier.name) })
     .joined(separator: "\n\n")
     .indented(by: 6)

    let publicFunctions = functions.filter { $0.functionDeclaration.isPublic }

    // Create a function selector, to determine which function is called in the Ethereum transaction.
    let functionSelector = IRFunctionSelector(fallback: findContractPublicFallback(), functions: publicFunctions, enclosingType: contractDeclaration.identifier, environment: environment)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    let initializerBody = renderPublicInitializer()

    // Main contract body.
    return """
    pragma solidity ^0.4.21;

    contract \(contractDeclaration.identifier.name) {

      \(initializerBody.indented(by: 2))

      function () public payable {
        assembly {
          // Memory address 0x40 holds the next available memory location.
          mstore(0x40, 0x60)

          \(selectorCode)

          //////////////////////////////////////
          //// -- User-defined functions -- ////
          //////////////////////////////////////

          \(functionsCode)

          //////////////////////////////////////
          //// --   Wrapper functions    -- ////
          //////////////////////////////////////

          \(wrapperCode)

          \(renderCommon(indentedBy: 6))
        }
      }
    }
    """
  }

  func renderStructFunctions() -> String {
    return structDeclarations.map { structDeclaration in
      return "//// \(structDeclaration.identifier.name)::\(structDeclaration.sourceLocation)  ////\n\n\(IRStruct(structDeclaration: structDeclaration, environment: environment).rendered())"
    }.joined(separator: "\n\n")
  }

  func renderRuntimeFunctions() -> String {
    return IRRuntimeFunction.allDeclarations.joined(separator: "\n\n")
  }

  func renderPublicInitializer() -> String {
    let (initializerDeclaration, contractBehaviorDeclaration) = findContractPublicInitializer()!

    let capabilityBinding = contractBehaviorDeclaration.capabilityBinding
    let callerCapabilities = contractBehaviorDeclaration.callerCapabilities

    let initializer = IRContractInitializer(initializerDeclaration: initializerDeclaration, typeIdentifier: contractDeclaration.identifier, propertiesInEnclosingType: contractDeclaration.variableDeclarations, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: true).rendered()

    let parameters = initializerDeclaration.signature.parameters.map { parameter in
      let parameterName = parameter.identifier.name.mangled
      return "\(CanonicalType(from: parameter.type.rawType)!.rawValue) \(parameterName)"
      }.joined(separator: ", ")

    return """
    constructor(\(parameters)) public {
      assembly {
        // Memory address 0x40 holds the next available memory location.
        mstore(0x40, 0x60)

        //////////////////////////////////////
        //// --      Initializer       -- ////
        //////////////////////////////////////

        \(initializer.indented(by: 4))

        \(renderCommon(indentedBy: 4))
      }
    }
    """
  }

  func renderCommon(indentedBy: Int) -> String {

     let structHeader = """
     //////////////////////////////////////
     //// --    Struct functions    -- ////
     //////////////////////////////////////
     """
     let runtimeHeader = """
     //////////////////////////////////////
     //// --     Flint Runtime      -- ////
     //////////////////////////////////////
     """

     // Generate code for each function in the structs.
     let structFunctions = renderStructFunctions()

     // Generate runtime functions.
     let runtimeFunctionsDeclarations = renderRuntimeFunctions()



     return """
     \(structHeader.indented(by: indentedBy))

     \(structFunctions.indented(by: indentedBy, andFirst: true))


     \(runtimeHeader.indented(by: indentedBy, andFirst: true))

     \(runtimeFunctionsDeclarations.indented(by: indentedBy, andFirst: true))
     """
   }

  /// Finds the contract's public initializer, if any is declared, and returns the enclosing contract behavior declaration.
  func findContractPublicInitializer() -> (SpecialDeclaration, ContractBehaviorDeclaration)? {
    let result = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> (SpecialDeclaration, ContractBehaviorDeclaration)? in
        guard case .specialDeclaration(let specialDeclaration) = member, specialDeclaration.isInit, specialDeclaration.isPublic else {
          return nil
        }
        return (specialDeclaration, contractBehaviorDeclaration)
      }
    }

    guard result.count < 2 else {
      fatalError("Too many initializers")
    }

    return result.first
  }

  /// Finds the contract's public fallback, if any is declared.
  func findContractPublicFallback() -> SpecialDeclaration? {
    let result = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> SpecialDeclaration? in
        guard case .specialDeclaration(let specialDeclaration) = member, specialDeclaration.isFallback, specialDeclaration.isPublic else {
          return nil
        }
        return specialDeclaration
      }
    }

    guard result.count < 2 else {
      fatalError("Too many fallbacks")
    }

    return result.first
  }
}
