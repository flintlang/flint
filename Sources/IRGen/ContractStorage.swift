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
}
