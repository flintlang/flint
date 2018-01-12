//
//  ContractStorage.swift
//  IRGen
//
//  Created by Franklin Schrans on 1/5/18.
//

struct ContractStorage {
  private var storage = [String: Int]()
  private var indexPool = 0

  var numAllocated: Int {
    return indexPool
  }

  @discardableResult
  mutating func nextIndex() -> Int {
    defer { indexPool += 1 }
    return indexPool
  }

  mutating func addProperty(_ property: String) {
    storage[property] = nextIndex()
  }

  mutating func allocate(_ numEntries: Int, for property: String) {
    addProperty(property)
    for _ in (1..<numEntries) { nextIndex() }
  }

  func offset(for property: String) -> Int {
    return storage[property]!
  }

  // Dictionaries
  private var dictionaryNumKeys = [String: Int]()

  mutating func freshKeyOffset(forDictionary dictionary: String) -> Int {
    let offset = dictionaryNumKeys[dictionary, default: 0]
    dictionaryNumKeys[dictionary, default: 0] += 1
    return offset
  }
}
