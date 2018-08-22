# Compilation and Running
Flint compiles to EVM bytecode, which can be deployed to the Ethereum blockchain using a standard client, or Truffle.

For testing purposes, the recommended way of running a contract is by using the Remix IDE.

## Using Remix
Remix is an online IDE for testing Solidity smart contracts. Flint contracts can also be tested in Remix, by compiling Flint to Solidity.

In this example, we are going to compile and run the `Counter` contract, available to download [here](https://github.com/franklinsch/flint/blob/master/examples/valid/counter.flint).

### Compiling
A Flint source file named `counter.flint` containing a contract `Counter` can be compiled to a Solidity file using:
```
flintc main.flint --emit-ir
```
You can view the generate code, embedded as a Solidity program:
```
cat bin/main/Counter.sol
```
Example smart contracts are available in the repository, under `examples/valid`.

---
## Interacting with contract in Remix
To run the generated Solidity file on Remix:

1. Copy the contents of  `bin/main/Counter.sol` and paste the code in Remix.

1. Press the red Create button under the Run tab in the right sidebar.

1. You should now see your deployed contract below. Click on the copy button on the right of `Counter` to copy the contract's address.

1. Select from the dropdown right above the Create button and select `_InterfaceMyContract`.

1. Paste in the contract's address in the "Load contract from Address" field, and press the At Address button.

1. You should now see the public functions declared by your contract (`getValue`, `set`, and `increment`). Red buttons indicate the functions are mutating, whereas blue indicated non-mutating.

You should now be able to call the contract's functions.
