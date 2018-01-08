//
//  ContractStorage.swift
//  IRGen
//
//  Created by Franklin Schrans on 1/5/18.
//

struct ContractStorage {
  private var storage = [String: Int]()
  private var indexPool = 0

  @discardableResult
  mutating func nextIndex() -> Int {
    defer { indexPool += 1 }
    return indexPool
  }

  mutating func addProperty(_ property: String) {
    storage[property] = nextIndex()
  }

  mutating func addArrayProperty(_ arrayProperty: String, size: Int) {
    addProperty(arrayProperty)
    for _ in (1..<size) { nextIndex() }
  }

  func offset(for property: String) -> Int {
    return storage[property]!
  }
}
