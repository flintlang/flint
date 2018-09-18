# Traits

* Proposal: [FIP-0004](0004-traits.md)
* Author: [Daniel Hails](https://github.com/djrhails)
* Review Manager: [Susan Eisenbach](https://github.com/SusanEisenbach)
* Status: **Awaiting review**

## Introduction

A trait is a collection of functions and events. It can access other methods declared in the same trait. Contracts or Structures can conform to a particular trait by implementing all of the trait's function stubs.

We introduce the concept of ‘traits’ to Flint based in part on [Rust Traits](https://doc.rust-lang.org/rust-by-example/trait.html). Traits describe the partial behaviour of Contract or Structures which conform to them. For Contracts, traits constitute a collection of functions and function stubs in restriction blocks, and events. For Structures, traits only constitute a collection of functions and function stubs.

Contract or Structures can conform to multiple traits. The Flint compiler enforces the implementation of function stubs in the trait and allows usage of the functions declared in them.


## Motivation
Traits allow a level of abstraction and code reuse for Contracts and Structures. We also plan to have Standard Library Traits that can be inherited which provide common functionality to Contracts (Ownable, Burnable, MultiSig, Pausable, ERC20, ERC721, etc.) and Structures (Transferable, RawValued, Describable etc).

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

In the example below, we define `Ownable`, which declares a contract as something that can be owned and transferred. The `Ownable` `trait` is then specified by the `ToyWallet` `contract` allowing the use of methods in `Ownable`. This demonstrates how we can expose contract properties:

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

In the example below, we define `Pausable`, which declares a contract as something that can be paused. The `Pausable` `trait` is then specified by the `ToyDAO` `contract` allowing the use of methods in `Pausable`. This demonstrates how we can have traits with type states:

```swift
trait Pausable @(Inactive, Active) {
  event Paused {}

  self @(any) :: (any) {
    public canCallerPause() -> Bool
  }

  self  @(Active) :: (canCallerPause) {
    public func pause(newOwner: Address) {
      become InActive
    }

  }

  self @(InActive) :: (canCallerPause) {
    public func unpause() {
      become Active
    }
  }
}

// Contracts need to conform to Pausable and include those states in its state declaration
contract ToyDAO: Pausable @(Inactive, Active) {
  var owner: Address
}

ToyDAO @(any) :: caller <- (any) {
  public canCallerPause() -> Bool {
    return caller == owner
  }
}

ToyDAO @(Active) :: (any) {
  // Normal Functions
}
```
## Semantics

## Alternatives considered

### Inheritance of Contracts / Structures
The same functionality that traits provide could have been provided by allowing inheritance of Contracts and Structures, in addition inheritance would also allow multiple levels of inheritance, while traits only allow one.

### Public by default
Functions declared in traits could have been public by default, removing the need for the public modifier for each function. This would however be inconsistent with Flint's private by default function policy.

### No implementation in traits
We could have limited traits to only enforce functions to be declared and not define any pre-existing functionality. This would have made them very similar to Solidity Interfaces. However for a little additional complexity we don't need to have two separate concepts for interfacing and functions.

### Syntax Alternatives

#### Keyword
```
contract Name @(State1, State2) {
  conforms Trait1, Trait2
}
```

#### Addition sign for multiple traits
```
contract Name: Trait1 + Trait2 + Trait3 {}
```

### Property Declaration
Accessors have a number of disadvantages. Of course there is the obvious one: they are tedious to define and to use. Writing `node.location().x` and `node.set_location(p)` is simply less nice than `node.location.x` and `node.location = p`. We could adopt a syntactic sugar by which the latter can be automatically translated to the former.

We would extend traits with an optional "field block" which would be a list of variable declarations. These could then be used within the trait according to their

```
trait Trait {
  let field1: Type1
  var field2: Type2
}
```

Conforming structures and contracts would have to then map field names to expressions.
```
contract Type: Trait {
  field1 -> self.x
  field2 -> self.y.z
}
```
These expressions must be of the form self(.F)* where F is some qualified field in the Contract / Structure. The properties will be checked to be compatible (same type, constant/variable match). You can't access the expression via the field name, only the trait will use this mapping.

### State Declaration
State declaration for contracts could be moved inside of the contract declaration as opposed to at the head.
```
contract Type {
  @ (State1, State2, State3)
}
```
This would reduce the worry about the initial declaration becoming too messy. Equally we can expand the Grammar and parser to support adding line breaks to the declaration.
```
contract Type: Trait1, Trait2, Trait3
         @(State1, State2) {
 // As normal from here on                
}
```
