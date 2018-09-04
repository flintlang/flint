
//
//  IRRuntimeFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

/// The runtime functions used by Flint.
enum IRRuntimeFunction {
  enum Identifiers: String {
    case decodeAsAddress = "Runtime$Memory$decodeAsAddress$Int"
    case decodeAsUInt = "Runtime$Memory$decodeAsUInt$Int"
    case store = "Runtime$Memory$store$Int_Int_Bool"
    case load = "Runtime$Memory$load$Int_Bool"
    case checkNoValue = "Runtime$Exception$checkNoValue$Int"
    case computeOffset = "Runtime$Memory$computeOffset$Int_Int_Int"
    case storageOffsetForKey = "Runtime$Memory$storageOffsetForKey$Int_Int"
    case allocateMemory = "Runtime$Memory$allocateMemory$Int"
    case storageDictionaryKeysArrayOffset = "$Dictionary$keysArrayOffset$Int"
    case isMatchingTypeState = "Runtime$TypeState$isMatchingTypeState$Int_Int"
    case isValidCallerCapability = "Runtime$CallerCapability$isValid$Int"
    case isCallerCapabilityInArray = "Runtime$CallerCapability$isInArray$Int"
    case isCallerCapabilityInDictionary = "Runtime$CallerCapability$isInDictionary$Int"
    case return32Bytes = "Runtime$Memory$return32Bytes$Int"
    case isInvalidSubscriptExpression = "$Array$isInvalidSubscript$Int"
    case storageArrayOffset = "$Array$storageOffset$Int_Int"
    case storageArraySize = "$Array$size"
    case storageFixedSizeArrayOffset = "$FixedSizeArray$storageOffset$Int_Int_Int"
    case storageDictionaryOffsetForKey = "$Dictionary$keyOffset$Int_Int"
    case callvalue = "Runtime$External$callvalue$Int"
    case send = "Runtime$External$send$Int_Int"
    case add = "Runtime$Math$add$Int_Int"
    case sub = "Runtime$Math$sub$Int_Int"
    case mul = "Runtime$Math$mul$Int_Int"
    case div = "Runtime$Math$div$Int_Int"
    case power = "Runtime$Math$power$Int_Int"
  }

  static func decodeAsAddress(offset: Int) -> String {
    return "\(Identifiers.decodeAsAddress.rawValue)(\(offset))"
  }

  static func decodeAsUInt(offset: Int) -> String {
    return "\(Identifiers.decodeAsUInt.rawValue)(\(offset))"
  }

  static func store(address: String, value: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mstore" : "sstore")(\(address), \(value))"
  }

  static func store(address: String, value: String, inMemory: String) -> String {
    return "\(Identifiers.store.rawValue)(\(address), \(value), \(inMemory))"
  }

  static func addOffset(base: String, offset: String, inMemory: Bool) -> String {
    return inMemory ? "add(\(base), mul(\(EVM.wordSize), \(offset)))" : "add(\(base), \(offset))"
  }

  static func addOffset(base: String, offset: String, inMemory: String) -> String {
    return "\(Identifiers.computeOffset.rawValue)(\(base), \(offset), \(inMemory))"
  }

  static func load(address: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mload" : "sload")(\(address))"
  }

  static func load(address: String, inMemory: String) -> String {
    return "\(Identifiers.load.rawValue)(\(address), \(inMemory))"
  }

  static func allocateMemory(size: Int) -> String {
    return "\(Identifiers.allocateMemory.rawValue)(\(size))"
  }

  static func checkNoValue(_ value: String) -> String {
    return "\(Identifiers.checkNoValue.rawValue)(\(value))"
  }

  static func isMatchingTypeState(_ stateValue: String, _ stateVariable: String) -> String {
    return "\(Identifiers.isMatchingTypeState.rawValue)(\(stateValue), \(stateVariable))"
  }

  static func isValidCallerCapability(address: String) -> String {
    return "\(Identifiers.isValidCallerCapability.rawValue)(\(address))"
  }

  static func isCallerCapabilityInArray(arrayOffset: Int) -> String {
    return "\(Identifiers.isCallerCapabilityInArray.rawValue)(\(arrayOffset))"
  }

  static func isCallerCapabilityInDictionary(dictionaryOffset: Int) -> String {
    return "\(Identifiers.isCallerCapabilityInDictionary.rawValue)(\(dictionaryOffset))"
  }

  static func return32Bytes(value: String) -> String {
    return "\(Identifiers.return32Bytes.rawValue)(\(value))"
  }

  static func isInvalidSubscriptExpression(index: Int, arraySize: Int) -> String {
    return "\(Identifiers.isInvalidSubscriptExpression.rawValue)(\(index), \(arraySize))"
  }

  static func storageArrayOffset(arrayOffset: String, index: String) -> String {
    return "\(Identifiers.storageArrayOffset.rawValue)(\(arrayOffset), \(index))"
  }

  static func storageArraySize(arrayOffset: String) -> String {
    return "\(Identifiers.storageArraySize.rawValue)(\(arrayOffset))"
  }

  static func storageOffsetForKey(offset: String, key: String) -> String {
    return "\(Identifiers.storageOffsetForKey.rawValue)(\(offset), \(key))"
  }

  static func storageFixedSizeArrayOffset(arrayOffset: String, index: String, size: Int) -> String {
    return "\(Identifiers.storageFixedSizeArrayOffset.rawValue)(\(arrayOffset), \(index), \(size))"
  }

  static func storageDictionaryOffsetForKey(dictionaryOffset: String, key: String) -> String {
    return "\(Identifiers.storageDictionaryOffsetForKey.rawValue)(\(dictionaryOffset), \(key))"
  }

  static func storageDictionaryKeysArrayOffset(dictionaryOffset: String) -> String {
    return "\(Identifiers.storageDictionaryKeysArrayOffset.rawValue)(\(dictionaryOffset))"
  }

  static func callvalue() -> String {
    return "\(Identifiers.callvalue)()"
  }

  static func add(a: String, b: String) -> String {
    return "\(Identifiers.add.rawValue)(\(a), \(b))"
  }

  static func sub(a: String, b: String) -> String {
    return "\(Identifiers.sub.rawValue)(\(a), \(b))"
  }

  static func mul(a: String, b: String) -> String {
    return "\(Identifiers.mul.rawValue)(\(a), \(b))"
  }

  static func div(a: String, b: String) -> String {
    return "\(Identifiers.div.rawValue)(\(a), \(b))"
  }

  static func power(b: String, e: String) -> String {
    return "\(Identifiers.power.rawValue)(\(b), \(e))"
  }
}
