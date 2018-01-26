# Cross-contract interactions

It is possible for Flint contracts to perform calls to external contracts.
A call to a foreign contracts requires importing the contract's source code or interface.

```swift
// We have access to the contract's source code or interface.
import ForeignContract

contract MyContract {
  var foreignContract: ForeignContract
}

MyContract :: (any) {
  mutating public func setContract(address: Address) {
    foreignContract = address as ForeignContract // address should contain a ForeignContract
  }

  public func getValue() -> Int {
    return foreignContract.getValue() // call is statically checked
  }
}

```
Importing a Solidity contract from Flint is also possible. More information is given in `docs/FFI.md`.

## Obtaining a contract's source code

A contract's source code can be imported by:

- Directly downloading its source files
- Providing a web URL
- Finding the Flint contract in the (future) Flint Package Manager
