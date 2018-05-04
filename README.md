# The Flint Programming Language [![Build Status](https://travis-ci.org/franklinsch/flint.svg?branch=master)](https://travis-ci.org/franklinsch/flint)

<img src="docs/flint_small.png" height="70">

Flint is a new type-safe, capabilities-secure, contract-oriented programming language specifically designed for writing robust smart contracts on Ethereum.

Flint is still in **active development**, and is not ready to be used in the real world yet.

Medium article: [Flint: A New Language for Safe Smart Contracts on Ethereum](https://medium.com/@fschrans/flint-a-new-language-for-safe-smart-contracts-on-ethereum-a5672137a5c7)

Academic paper: [Writing Safe Smart Contracts in Flint](https://www.doc.ic.ac.uk/~fs2014/flint.pdf)

## Language Overview

The [Flint Programming Language Guide](https://docs.flintlang.org/) gives a high-level overview of the language, and helps you getting started with smart contract development in Flint.

Flint is still under active development and proposes a variety of novel _contract-oriented_ features.

### Caller Capabilities

[**Caller capabilities**](https://docs.flintlang.org/caller-capabilities) require programmers to think about who should be able to call the contract’s sensitive functions. Capabilities are checked statically for internal calls (unlike Solidity modifiers), and at runtime for calls originating from external contracts.

Example:

```swift
// State declaration
contract Bank {
  var manager: Address
}

// Functions are declared in caller capability blocks,
// which specify which users are allowed to call them.
Bank :: (manager) { // manager is a state property.

  // Only `manager` of the Bank can call `clear`.
  func clear(address: Address) {
    // body
  }
}

// Anyone can initialize the contract.
Bank :: (any) {
  public init(manager: Address) {
    self.manager = manager
  }
}
```

### Immutability by default

**Restricting writes to state** in functions helps programmers more easily reason about the smart contract. A function which writes to the contract’s state needs to be annotated with the `mutating` keyword.

Example:

```swift
Bank :: (any) {
  mutating func incrementCount() {
    // count is a state property
    count += 1
  }
  
  func getCount() -> Int {
    return count
  }
  
  func decrementCount() {
    // error: Use of mutating statement in a nonmutating function
    // count -= 1
  }
}
```

### Asset types

[**Assets**](https://docs.flintlang.org/assets), such as Ether, are often at the center of smart contracts. Flint puts assets at the forefront through the special _Asset_ trait.

Flint's Asset type ensure a contract's state always truthfully represents its Ether value, preventing attacks such as TheDAO.

A restricted set of atomic operations can be performed on Assets. It is impossible to create, duplicate, or lose Assets (such as Ether) in unprivileged code. This prevents attacks relating to double-spending and re-entrancy.

Example use:

```swift
Bank :: account <- (balances.keys) {
  @payable
  mutating func deposit(implicit value: inout Wei) {
    // Omitting this line causes a compiler warning: the value received should be recorded.
    balances[address].transfer(&value)
  }

  mutating func withdraw() {
    // balances[account] is automatically set to 0 before transferring.
    send(account, &balances[account])
  }
}
```

The Asset feature is still in development. The [FIP-0001: Introduce the Asset trait](proposals/0001-asset-trait.md) proposal includes more details.

### Safer semantics

In the spirit of reducing vulnerabilities relating to unexpected language semantics, such as wrap-arounds due to integer overflows, Flint aims to provide safer operations. For instance, arithmetic operations on `Int` are safe by default: an overflow/underflow causes the Ethereum transaction to be reverted.

## Installation

The Flint compiler and its dependencies can be installed using Docker:

```bash
docker pull franklinsch/flint
docker run -i -t franklinsch/flint
```

Example smart contracts are available in `flint/examples/valid/`.

Instructions for installing using a binary package or from source are available [here]( https://docs.flintlang.org/installation).

## Contributing

Contributions to Flint are highly welcomed!
The Issues page tracks the tasks which have yet to be completed.

Flint Improvement Proposals (FIPs) track the design and implementation of larger new features for Flint or the Flint compiler. An example is [FIP-0001: Introduce the Asset trait](proposals/0001-asset-trait.md).

## Future plans

Future plans for Flint are numerous, and include:

1. **Gas estimation**: provide estimates about the gas execution cost of a function. Gas upper bounds are emitted as part of the contract's interface, making it possible to obtain the estimation of a call to an external Flint function.
2. **Formalization**: specify well-defined semantics for the language.
3. **The Flint Package Manager**: create a package manager which runs as a Flint smart contract on Ethereum. It will store contract APIs as well as safety and gas cost information of dependencies.
4. **Tooling**: build novel tools around smart contract development, such as new ways of simulating and visualizing different transaction orderings.

## License

The Flint project is available under the MIT license. See the LICENSE file for more information.
