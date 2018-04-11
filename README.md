# The Flint Programming Language [![Build Status](https://travis-ci.org/franklinsch/flint.svg?branch=master)](https://travis-ci.com/franklinsch/flint)

<img src="docs/flint_small.png" height="70">

Flint is a new type-safe, capabilities-secure, contract-oriented programming language specifically designed for writing robust smart contracts on Ethereum.

Flint is still in active development, and is not ready to be used in the real world just yet.

## Documentation

The [Flint Programming Language Guide](https://franklinsch.gitbooks.io/flint/) gives a high-level overview of the language, and helps you getting started with smart contract development in Flint.

## Contributing

Contributions to Flint are highly welcomed!
The Issues page tracks the tasks which have yet to be completed.

## Future plans

Future plans for Flint are numerous, and include:

1. **Gas estimation**: provide estimates about the gas execution cost of a function. Gas upper bounds are emitted as part of the contract's interface, making it possible to obtain the estimation of a call to an external Flint function.
2. **Formalization**: specify well-defined semantics for the language.
3. **The Flint Package Manager**: create a package manager which records contract APIs as well as safety and gas cost information of dependencies, aka _Flint stones_.
4. **Tooling**: build novel tools around smart contract development, such as new ways of simulating and visualizing different transaction orderings.

## License

The Flint project is available under the MIT license. See the LICENSE file for more information.
