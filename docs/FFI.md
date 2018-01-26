# Flint Foreign Function Interface

Flint smart contract can call functions from Solidity smart contracts and vice-versa, thanks to the Flint Foreign Function Interface (FFI). 

The Flint FFI allows smart contracts to import a Solidity contract, in order to statically check the validity of external function calls.

```swift
@foreign import ForeignContract // A Solidity contract

contract Foo {}

Foo :: (any) {
  func foo(address: Address) -> Int {
    return (address as ForeignContract).getValue()
  }
}

```
