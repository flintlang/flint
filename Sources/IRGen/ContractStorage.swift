//
//  ContractStorage.swift
//  IRGen
//
//  Created by Franklin Schrans on 1/5/18.
//

import AST

struct ContractStorage {
  private var indexPool = 0

  var numAllocated: Int {
    return indexPool
  }

  @discardableResult
  mutating func nextIndex() -> Int {
    defer { indexPool += 1 }
    return indexPool
  }

  mutating func allocate(_ numEntries: Int, for property: String) {
    for _ in (1..<numEntries) { nextIndex() }
  }

  // Dictionaries
  private var dictionaryNumKeys = [String: Int]()

  mutating func freshKeyOffset(forDictionary dictionary: String) -> Int {
    let offset = dictionaryNumKeys[dictionary, default: 0]
    dictionaryNumKeys[dictionary, default: 0] += 1
    return offset
  }
}
