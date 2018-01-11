# The Flint Programming Language [![Build Status](https://travis-ci.com/franklinsch/flint.svg?token=QwcCuJTEqyvvqgtqAD5V&branch=master)](https://travis-ci.com/franklinsch/flint)

Flint is a new type-safe, capabilities-secure, contract-oriented programming language specifically designed for writing robust smart contracts.

Currently, the Flint compiler, `flintc`, targets the Ethereum Virtual Machine. 

## Smart contracts

Smart contracts are decentralized applications running on Ethereum's blockchain.

Once a smart contract is deployed, it is stored on the blockchain until a user performs a call to one of its functions. A contract, deployed at an address, can mutate its internal state through function calls. It is not possible to update a deployed contract at the same address.

Flint uses **caller capabilities** to easily set restrictions on which users can call a contract function. More details are given in `docs/CallerCapabilities.md`.

Functions in Flint are by default **non-mutating**: they are not allowed to modify the contract's state. This allows to more easily reason about functions in isolation. Functions can mutate the state by being declared as "mutating".

### Example: `Bank.flint`

The following code declares the `Bank` contract and its functions.

```swift
// Contract declarations contain only their state properties
contract Bank {
  var manager: Address
  var accounts: [Address: Int]
}

// The functions in this block can be called by any user
Bank :: (any) {
  // Functions can only mutate the state of the contract if 
  // declared "mutating"
  public mutating func deposit(address: Address, amount: Int) {
    accounts[address] += amount
  }
}

// Only the manager can call clear
Bank :: (manager) {
  public mutating func clear(address: Address) {
    accounts[accountIndex] = 0
  }
} 

// Any user registered in accounts' keys can call these functions
// The matching user's address is bound to the variable a
Bank :: (a <- anyOf(accounts.keys)) {
  public mutating func withdraw(amount: Int, recipient: Address) {
    let value = accounts[a]
    accounts[a] -= amount
    send(value, recipient)
  }
  
  // This function is non-mutating
  public func getBalance() -> Int {
    return accounts[a]
  }
}

```

## Declaring a contract

An `.flint` source file contains contract declarations. A contract is declared by specifying its identifier, and property declarations. Properties constitute the state of a smart contract.

Consider the following example.

```swift
contract Bank {
  var manager: Address
  var accounts: [Address: Int]
}
```

This is the declaration of the `Bank` contract, which contains two properties. The `manager` property has type `Address`, and `accounts` is a dictionary, or mapping, from `Address` to `Int`.

## Specifying the behavior of a contract

The behavior of a contract is specified through contract behavior declarations.

Consider the following example.

```swift
Bank :: (any) {
  public mutating func deposit(address: Address, amount: Int) {
    accounts[address] += amount
  }
}
```

This is the contract behavior declaration for the `Bank` contract, for callers which have the `any` capability (more info in `docs/CallerCapabilities.md`).

The function `deposit` is declared as `public`, which means that anyone on the blockchain can call it.

`deposit` is declared as `mutating`, and has to be: its body mutates the state of the contract. Functions are nonmutating by default.

## Future plans

Futures plans for Flint are numerous, and include:

1. **Cross-contract caller capabilities**: support static-checking of caller capabilities when calling a function of another Flint contract.
2. **Gas estimation**: provide estimates about the gas execution cost of a function. Gas upper bounds are emitted as part of the contract's interface, making it possible to obtain the estimation of a call to an external Flint function.
3. **Formalization**: specify well-defined semantics for the language.
4. **Tooling**: build novel tools around smart contract development, such as new ways of simulating and visualizing different transaction orderings.
