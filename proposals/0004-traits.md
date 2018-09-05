# Traits

* Proposal: [FIP-0004](0004-traits.md)
* Author: [Daniel Hails](https://github.com/djrhails)
* Review Manager: [Susan Eisenbach](https://github.com/SusanEisenbach)
* Status: **Awaiting review**

## Introduction

A trait is a collection of functions and events. They can access other methods declared in the same trait. Traits can be implemented for Contracts or Structures.

We introduce the concept of ‘Traits’ to Flint based in part on [Rust Traits](https://doc.rust-lang.org/rust-by-example/trait.html). Traits describe the partial behaviour of Contract or Structures declared to have them. For Contracts traits constitute a collection of functions or function stubs in restriction blocks, and events. For Structures, traits only constitute a collection of functions or function stubs.

Multiple traits can be declared for each Contract/Structure. When declared the Flint compiler enforces the implementation of function stubs in the trait and allows usage of functions declared in them.


## Motivation
Traits allow a level of abstraction and code reuse for Contracts and Structures. We also plan to have Standard Library Traits that can be inherited which provide common functionality to Contracts (Ownable, Burnable, MutiSig, Pausable, ERC20, ERC721 etc) and Structures (Transferable, RawValued, Describable etc).

It will also form the basis for allowing end users to access compiler level guarantees and restrictions as in [Assets](0001-asset-trait.md) and Numerics.

## Proposed Solution
In the example below, we define `ERC20`, which declares a contract to follow the Ethereum token specifications. The `ERC20` `trait` is then specified by the `ToyToken` `contract` allowing use of functions and events in `ERC20`.
```swift
trait ERC20 {
  event Transfer {
    let from: Address
    let to: Address
    let value: Int
  }
  event Approval {
    let from: Address
    let to: Address
    let value: Int
  }

  self :: (any) {
    public func totalSupply() -> Int
    public func balanceOf(owner: Address) -> Int
    public func allowance(owner: Address, spender: Address) -> Int

    public mutating func transfer(to: Address, value: Int) -> Bool
    public mutating func approve(spender: Address, value: Int) -> Bool
    public mutating func transferFrom(from: Address, to: Address, value: Int) -> Bool
  }
}

contract ToyToken: ERC20 {
  var balances: [Address: Int] = [:]
  var allowed: [Address: [Address: Int]] = [:]
  var totalSupply: Int = 0
}

ToyToken :: (any) {
  public init() {}
  public func totalSupply() -> Int {
    return totalSupply
  }
  public func balanceOf(owner: Address) -> Int {
    return balances[owner]
  }
  public func allowance(owner: Address, spender: Address) -> Int {
    return allowed[owner][spender]
  }
}

ToyToken :: caller <- (any) {
  public mutating func transfer(to: Address, value: Int) -> Bool {
    balances[caller] -= value
    balances[to] += value
    emit Transfer(from: caller, to: to, value: value)
    return true;
  }
  public mutating func approve(spender: Address, value: Int) -> Bool {
    allowed[caller][spender] = value
    emit Approval(from: caller, to: spender, value: value)
    return true
  }
  public mutating func transferFrom(from: Address, to: Address, value: Int) -> Bool {
    balances[from] -= value
    balances[to] += value
    allowed[from][caller] -= value
    emit Transfer(from: from, to: to, value: value)
    return true
  }
}
```

In the example below, we define `Ownable`, which declares a contract as something that can be owned and transfered. The `Ownable` `trait` is then specified by the `ToyWallet` `contract` allowing the use of methods in `Ownable`. This demonstrates how we can expose contract properties:

```swift
trait Ownable {
  event OwnershipRenounced {
    let previousOwner: Address
  }
  event OwnershipTransfered {
    let previousOwner: Address
    let newOwner: Address
  }

  self :: (any) {
    public getOwner() -> Address
  }

  self :: (getOwner) {
    func setOwner(newOwner: Address)

    public func renounceOwnership() {
      emit OwnershipRenounced(getOwner())
      setOwner(0x000...)
    }
    public func transferOwnership(newOwner: Address) {
      assert(newOwner != 0x000...)
      emit OwnershipTransfered(getOwner(), newOwner)
      setOwner(newOwner)
    }
  }
}

contract ToyWallet: Ownable {
  visible var owner: Address // visible automatically creates getOwner
}
// Skipping initialiser as not relevant for this example

ToyWallet :: (getOwner) {
  func setOwner(newOwner: Address){
    self.owner = newOwner
  }
}

```


## Motivation

### ERC20
```swift
trait ERC20 {
  event transfer {
    let from: Address
    let to: Address
    let value: Int
  }
  event approval {
    let from: Address
    let to: Address
    let value: Int
  }

  self :: caller <- (any) {
    public func totalSupply() -> Int
    public func balanceOf(owner: Address) -> Int
    public func allowance(owner: Address, spender: Address) -> Int

    public mutating func transfer(to: Address, value: Int) -> Bool
    public mutating func approve(spender: Address, value: Int) -> Bool
    public mutating func transferFrom(from: Address, to: Address, value: Int) -> Bool
  }
}
```

### Contract Types
```swift

```
## Proposed Solution

## Semantics

## Alternatives considered

##
