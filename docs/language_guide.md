
# Language Guide

:+1::tada: First of all, thank you for the interest in Flint! :tada::+1:

Even though the [Ethereum](https://www.ethereum.org/) platform requires smart contract programmers to ensure the correct behaviour of their program before deployment, it has not seen a language designed with safety in mind. Solidity and others do not tailor for Ethereum’s unique programming model and instead, mimic existing popular languages like JavaScript, Python, or C, without providing additional safety mechanisms.

Flint changes that, as a new programming language built for easily writing safe Ethereum smart contracts. Flint is approachable to both experienced and new Ethereum developers, and presents a variety of security features. Much of the language syntax is inspired by [the Swift language](https://swift.org/), making it more approachable than Solidity.

Flint also supports [Libra](https://github.com/libra/libra), Facebook's new block-chain, targeting Move, the IR for programmes on it. This is still somewhat experimental, especially as the blockchain is still only at the test-net stage, however, it does provide a much easier way of writing contracts _(modules)_ on Libra, and is easily extensible as Libra develops.

For a quick start, please have a look at the [Installation](#installation) section first, followed by the [Example](#example) section.

# Table of Contents

 - [**Getting started**](#getting-started)
   - [Installation](#installation)
     - [Building from source](#building-from-source)
     - [Installing `solc`, the Solidity compiler](#installing-solc-the-solidity-compiler)
     - [Docker](#docker)
     - [Binary packages](#binary-packages)
   - [Usage](#usage)
   - [Example](#example)
     - [Creating a simple contract](#creating-a-simple-contract)
     - [Compiling `Counter`](#compiling-counter)
     - [Testing `Counter`](#testing-counter)
     - [Deploying `Counter`](#deploying-counter)
   - [IDE integration](#ide-integration)
     - [VS Code](#vs-code)
     - [Vim](#vim)
     - [Atom](#atom)
   - [Compilation](#compilation)
   - [Remix integration](#remix-integration)
 - [**Language guide**](#language-guide-1)
   - [File structure](#file-structure)
     - [Comments](#comments)
   - [Types](#types)
     - [Basic types](#basic-types)
     - [Dynamic types](#dynamic-types)
     - [Range types](#range-types)
     - [Solidity types](#solidity-types)
   - [Constants and variables](#constants-and-variables)
   - [Functions](#functions)
     - [Function attributes](#function-attributes)
     - [Function modifiers](#function-modifiers)
     - [Function parameters](#function-parameters)
     - [Return values](#return-values)
     - [Initialisers](#initialisers)
     - [Payable](#payable)
     - [Fallback](#fallback)
   - [Structs](#structs)
     - [Declaration](#declaration)
     - [Instances](#instances)
     - [Accessing properties/methods](#accessing-propertiesmethods)
     - [Structs as function arguments](#structs-as-function-arguments)
   - [Contracts](#contracts)
     - [Declaration](#declaration-1)
     - [Type states](#type-states)
     - [Protection blocks](#protection-blocks)
       - [Caller group](#caller-group)
       - [Caller group variable](#caller-group-variable)
       - [Type state protection](#type-state-protection)
       - [Static checking](#static-checking)
       - [Dynamic checking](#dynamic-checking)
       - [Multiple protections](#multiple-protections)
     - [Visibility modifiers](#visibility-modifiers)
     - [Events](#events)
   - [Traits](#traits)
     - [Struct traits](#struct-traits)
     - [Contract traits](#contract-traits)
     - [External traits](#external-traits)
     - [Polymorphic self](#polymorphic-self)
   - [Expressions](#expressions)
     - [Function calls](#function-calls)
   - [Literals](#literals)
     - [Integer literals](#integer-literals)
     - [Address literals](#address-literals)
     - [Boolean literals](#boolean-literals)
     - [String literals](#string-literals)
     - [List literals](#list-literals)
     - [Dictionary literals](#dictionary-literals)
     - [Self](#self)
   - [Operators](#operators)
     - [Arithmetic operators](#arithmetic-operators)
     - [Boolean operators](#boolean-operators)
   - [Statements](#statements)
     - [Variable/constant declaration and assignment](#variableconstant-declaration-and-assignment)
       - [Compound assignment](#compound-assignment)
     - [Loops](#loops)
     - [Conditionals](#conditionals)
       - [Else clauses](#else-clauses)
     - [Become statements](#become-statements)
     - [Return statements](#return-statements)
     - [Do-catch statements](#do-catch-blocks)
   - [External calls](#external-calls)
     - [Specifying the interface](#specifying-the-interface)
     - [Creating an instance](#creating-an-instance)
     - [Calling functions](#calling-functions)
     - [Specifying hyper-parameters](#specifying-hyper-parameters)
     - [Casting to and from Solidity types](#casting-to-and-from-solidity-types)
   - [Enumerations](#enumerations)
     - [Associated values](#associated-values)
 - [**Standard library**](#standard-library)
   - [Assets](#assets)
   - [Global functions](#global-functions)
     - [Assertions](#assertions)
     - [Fatal error](#fatal-error)
     - [Send](#send)

---

# Getting started

## Installation

The first step before using the Flint compiler is to install it. The simplest way is to use [Docker](#docker), though this is currently not recommended, except for casual usage. Otherwise, the [binary packages](#binary-packages) and [building from source](#building-from-source) require [`solc` to be installed first](#installing-solc-the-solidity-compiler).

### Installing `solc`, the Solidity compiler

A non-Docker Flint install requires the [Solidity](https://github.com/ethereum/solidity) compiler `solc` (version 0.4.25) to be installed. For full installation instructions, see the [Solidity documentation](https://solidity.readthedocs.io/en/latest/installing-solidity.html). You can get the `solc` binary from https://github.com/ethereum/solidity/releases/tag/v0.4.25.

### Building from source
_This is currently the advised way of installing Flint_

#### Prerequisites
The following must be installed to build Flint:
* mono 5.20 or later (C# 7.0)
* swiftenv
* clang
* nodejs npm
* swiftlint

##### Additionally for testing
To run the testing libraries, install:
* truffle 4

##### macOS
* xcode - preferences/Locations/Command Line tools must not be empty (the default)
* homebrew - https://brew.sh, update brew if it isn't new with brew update
* `brew install node` - get node and npm if you don't have them
* `brew install wget` - get wget if you don't have it
* `brew cask install mono-mdk`
* swiftenv, which can be installed as follows

```bash
git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bashrc
echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(swiftenv init -)"' >> ~/.bashrc
```

#### Install
Assuming you have all the prerequisites, you should be able to build flint by running

```bash
git clone --recurse-submodules https://www.github.com/flintlang/flint.git $HOME/.flint
cd $HOME/.flint
make release
echo "export PATH=$HOME/.flint/.build/release/:$PATH" >> ~/.bashrc
source ~/.bashrc
```

##### Ubuntu 18.04 LTS
This assumes a standard Ubuntu build with `apt`, `wget`, `curl`, `gnupg`, `ca-certificates` and `git` installed. If you don't have one of them installed, you should be notified during the process. If you have any kind of error, try installing them. Note Ubuntu 16.04 has different installation procedures when using apt and installing Mono, thus the process would need to be done manually. You may find the [18.04 install script](https://raw.githubusercontent.com/flintlang/flint/master/utils/install_ubuntu_18_04.sh) a good place to start on what you need to install it.

```bash
bash <(curl -s https://raw.githubusercontent.com/flintlang/flint/master/utils/install_ubuntu_18_04.sh)
```

### Docker

To use Flint in  a [Docker](https://www.docker.com/) container run the following: 

```bash
git clone --recurse-submodule https://github.com/flintlang/flint.git
cd flint
sudo docker build -t "flint_docker" .
#### ---------------------------------------------- ###
## Docker will build, this process may take some time #
#### ---------------------------------------------- ###
sudo docker run --privileged -i -t flint_docker
## Then, inside the docker container, run
source ~/.bash_profile
```

### Binary packages
_Currently not maintained and out of date_

Flint is compatible with macOS and Linux platforms, and can be installed by downloading a built binary directly. Installing `solc` is a pre-requisite for using the binary packages.

The latest releases are available on the [GitHub releases page](https://github.com/flintlang/flint/releases).


## Usage

To use Flint to compile a Flint contract (in this example `counter.flint`) into Solidity code, run the following code from inside the Flint project folder:

```bash
flintc --emit-ir --ir-output ./bin examples/valid/counter.flint
```

This will generate a `main.sol` file inside the bin sub-directory which can then be compiled to be deployed on the Etherum block-chain. If you wish to have the output file in the current directory remove bin from the previous command:

```bash
flintc --emit-ir --ir-output ./<destination> examples/valid/counter.flint
```

To test it, we recommend using Remix IDE, following [these instructions](https://docs.flintlang.org/docs/language_guide#remix-integration)

## Example

This section demonstrates the full workflow of writing a smart contract in Flint, compiling it, testing it locally using Truffle, and deploying it to the Ethereum network.

### Creating a simple contract

The first step is to create a Flint source file. Our example smart contract will be a simple counter. It will have a state – the number of "hits". Its current value can be displayed by calling its `getValue` function. Its value can be increased by paying some Wei to its `hit` function.

We create a file called `main.flint` and put the following code in it:

```swift
// This is the declaration of the contract. In this simple example, it only
// includes the one state variable, `hits`.
contract Counter {
  // `hits` will initially be `0` and it will be an integer variable (`Int`).
  var hits: Int = 0
}

// These are the functions of the contract. The `:: (any)` indicates that
// these functions can be called by anyone on the Ethereum network.
Counter :: (any) {
  // This is the constructor, called when the contract is first created. There
  // is nothing we need to do here at this point, so it is empty.
  public init() {}

  // This function returns the current counter value. It takes no arguments,
  // but returns an `Int`.
  public func getValue() -> Int {
    return hits
  }

  // This function increates the counter value by one. It only does this if
  // some Wei was paid, so the function is `@payable`. The amount of Wei paid
  // is available as the implicit `value` argument, although we do not use this
  // value here.
  @payable
  public func hit(implicit value: Wei) mutates (hits) {
    hits += 1
  }
}
````

### Compiling `Counter`

We can compile `Counter` to the Solidity contract file `contracts/main.sol` using the terminal command:

```bash
$ flintc main.flint --emit-ir --ir-output contracts
```

### Testing `Counter`

Even though `Counter` is extremely simple, we should test it before deploying it to the Ethereum network.

During early iterations, it may be useful to debug a contract directly with the Remix IDE. This is detailed in a [separate section](#remix-integration).

Writing unit tests for Solidity (and hence Flint) contracts is possible with the Truffle framework. Unfortunately, it is necessary to provide some boilerplate code for the tests to work. This consists of:

 1. Create a `Migrations.sol` file in the `contracts` directory (alongside the Flint-generated `main.sol`) with the content:
    ```solidity
    pragma solidity ^0.4.2; contract Migrations {}
    ```
 2. Create a `1.js` file in a new directory called `migrations` with the content:
    ```javascript
    var Contract = artifacts.require("./Counter.sol");
    module.exports = (deployer) => deployer.deploy(Contract);
    ```
  1. Create a `truffle.js` file with the content:
    ```javascript
    module.exports = {};
    ```

Finally, we can create a `test.js` file with the unit tests:

```javascript
var Contract = artifacts.require("./Counter.sol");
var Interface = artifacts.require("./_InterfaceCounter.sol");
Contract.abi = Interface.abi;

contract("Counter", function(accounts) {
  it("should be possible to deploy the counter", async function() {
    await Contract.deployed();
  });
  it("should be possible to increase the counter value", async function() {
    let counter = await Contract.deployed();
    await counter.deposit({value: 10});
  });
  it("should have a zero value initially", async function() {
    let counter = await Contract.deployed();
    let value = await counter.getValue();
    assert.equal(value.valueOf(), 0);
  });
  it("should be possible to interact with the counter", async function() {
    let counter = await Contract.deployed();
    var value;

    value = await counter.getValue();
    assert.equal(value.valueOf(), 0);

    await counter.deposit({value: 10});

    value = await counter.getValue();
    assert.equal(value.valueOf(), 1);

    value = await counter.getValue();
    assert.equal(value.valueOf(), 1);

    await counter.deposit({value: 10});

    value = await counter.getValue();
    assert.equal(value.valueOf(), 2);

    await counter.deposit({value: 10});

    await counter.deposit({value: 10});

    value = await counter.getValue();
    assert.equal(value.valueOf(), 4);
  });
});
```

We can then run these unit tests using:

```bash
$ truffle test test.js
```

### Deploying `Counter`

Finally, we can deploy our contract to the Ethereum network. Note that this may cost real money and the `Counter` contract is not terribly useful!

Since Flint produces Solidity contracts, they can be deployed by following a standard guide, such as [this one](https://medium.com/mercuryprotocol/dev-highlights-of-this-week-cb33e58c745f).

## IDE integration

The Flint compiler has options to integrate with [VS Code](#vs-code), [Vim](#vim), and [Atom](#atom), although Vim and Atom currently only support syntax highlighting, not inline error / warning display.

### VS Code

Experimental support is provided for VS Code via a [LSP](https://langserver.org/) plugin available at https://github.com/flintrocks/vscode-flint. The `vscode-flint` repository needs to be opened in VS Code as a project, then run in debug mode. Assuming the Flint compiler was built and the `langsrv` executable was created, this should provide errors and diagnostics in Flint files.

### Vim

Syntax highlighting can be activated in Vim by using the following command in the Flint repository:

```bash
$ ditto utils/vim ~/.vim
```

### Atom

Syntax highlighting in Atom can be obtained by installing the [`language-flint` package](https://atom.io/packages/language-flint).

## Compilation

Flint compiles Flint source code to [YUL IR](https://solidity.readthedocs.io/en/latest/yul.html) wrapped in Solidity contracts. These can then be compiled into EVM bytecode using the Solidity compiler, and deployed to the Ethereum blockchain using a standard client or the Truffle framework. It also compiles them to MoveIR modules, using the `--target move` flag.

A Flint source file named `main.flint` containing a contract `Counter` can be compiled to a Solidity file using:

```bash
$ flintc main.flint --emit-ir
```

You can view the generated code using:

```bash
$ cat bin/main/Counter.sol
```

The Solidity compiler `solc` can be used to compile `.sol` files to EVM bytecode. This step can be done automatically by `flintc` (internally invoking `solc`) instead by using:

```bash
$ flintc main.flint --emit-bytecode
```

There are more command-line options available in `flintc`. To show a full listing, use:

```bash
$ flintc --help
```

## Remix integration

[Remix](https://remix.ethereum.org/) is an online IDE for testing Solidity smart contracts. Flint contracts can also be tested in Remix, by compiling Flint to Solidity. In this example, we are going to test the `Counter` contract from the [example section](#example)

After [compiling](#compilation) the `Counter` contract, we can obtain the Solidity program in the file `bin/main/Counter.sol`. To interact with this contract in Remix:

 1. Copy the contents of `bin/main/Counter.sol` and paste the code into Remix.
 2. Press the red Create button under the Run tab in the right sidebar.
 3. You should now see your deployed contract below. Click on the copy button on the right of `Counter` to copy the address of the deployed contract.
 4. Select `_InterfaceMyContract` from the dropdown above the Create button.
 5. Paste the contract address (from step 3) into the "Load contract from Address" field, and press the At Address button.
 6. You should now see the public functions declared by your contract (`getValue`, `hit`). Red buttons indicate the functions are mutating, whereas blue indicated non-mutating. You should now be able to call the contract's functions.

# Language guide

## File structure

Flint files consist of one or more [contract declarations](#contracts), and optionally [struct declarations](#structs), [trait declarations](#traits), [external contract declarations](#external-calls), and/or [enumerations](#enumerations).

### Comments

Comments may be used throughout the source code. Comments are started with a double slash `//` and continue to the end of that line.

## Types

Flint is a statically-typed language with a simple type system, with basic support for subtyping through [traits](#traits).

 > **Planned feature**
 >
 > Currently, the types of all constants, variables, function arguments, etc. have to be explicitly declared. Type inference is a planned feature.

Flint is a type-safe language. A type safe language encourages clarity about the types of values your code can work with. It performs type checks when compiling code and flags any mismatched types as errors. This enables you to catch and fix errors as early as possible in the development process.

### Basic types

| Type | Description |
| --- | --- |
| `Int` | 256-bit integer. |
| `Address` | 160-bit Ethereum address. |
| `Bool` | Boolean value. |
| `String` | String value. Currently limited to 256 bits, i.e. 32 bytes. |
| `Void` | Non-value. Note that the `Void` type is never directly used. It is implicit when a function has no return type. |

### Dynamic types

| Name | Type (in code) | Description |
| --- | --- | --- |
| Dynamic-size list | `[T]` | A list of elements of type `T`. Elements can be added to it or removed from it. |
| Fixed-size list | `T[n]` | A list containing `n` elements of type `T`. It cannot have a different number of elements than its declared capacity `n`. |
| Dictionary | `[K: V]` | Dynamic-size mappings from one key type `K` to a value type `V`. Each stored key of type `K` is associated with one value of type `V`. |
| Polymorphic self | `Self` | See [polymorphic self](#polymorphic-self). |
| Structs | | Structs (structures), including [user-defined structs](#structs). |

> **Warning**
>
> As MoveIR doesn't yet support collections, no collection types work when `target --move` is set

> **Planned feature**
>
> When MoveIR supports collections, arrays and dictionaries will work in Move-targeted code

### Range types

Flint includes two range types, which are shortcuts for expressing ranges of values. These can only be used with `for-in` loops.

The half-open range (`a..<b`) defines a range that runs from `a` to `b`, but does not include `b`.

```swift
for let i: Int in (0..<5) {
  // i will be 0, 1, 2, 3, 4 on separate iteratons
}
```

The open range operator (`a...b`) defines a range that runs from `a` to `b` and does include `b`.

```swift
for let i: Int in (0...5) {
  // i will be 0, 1, 2, 3, 4, 5 on separate iteratons
}
```

At the moment, both `a` and `b` must be integer literals, not variables!

 > **Planned feature**
 >
 > In the future, it will be possible to iterate up to an arbitrary value. See https://github.com/flintlang/flint/issues/397.

### External types

When specifying an [external interface](#external-calls), External types must be used. The types usable in Flint are:

 - `int8`, `int16`, `int24`, ... `int256` (all multiples of 8 bits)
 - `uint8`, `uint16`, `uint24`, ... `uint256` (all multiples of 8 bits)
 - `address`
 - `string`
 - `bool`
 - `bytes32`

> Note that only `bool`, `uint64`, `address` are available in MoveIR due to target restrictions

See [casting](#casting-to-and-from-solidity-types) for more information.

## Constants and variables

Constants and variables associate a name with a value of a particular [type](#types). The value of a constant cannot be changed once it is set, whereas a variable can be set to a different value with assignment statements.

Constants and variables of a contract are its state properties. They are data stored in the EVM storage, and even though they are not directly modifiable, they are publicly visible, so they should never hold private or sensitive data.

Otherwise, local constants and variables are declared inside functions. These are specific to a given transaction, stored in the EVM memory. Even though these terms are not part of a contract's state, if they are part of an executed transaction their values will still be recorded in the transaction history.

To declare a constant with the name `<name>` of the type `<type>` with the initial value being the result of `<expression>`:

```swift
let <name>: <type> = <expression>
```

The expression is evaluated once, when the declaration is executed. The expression can be complex, or just a simple [literal](#literals). Examples:

```swift
let unity: Int = 1
let answer: Int = 7 * 6
let usingFlint: Bool = true
let digitsOfPi: [Int] = [3, 1, 4, 1, 5, 9, 2, 6]
let structExample: Rectangle = Rectangle(width: 30, height: 40)
```

If a constant is a state property of a contract, it may be given no initial value, but in that case it must be set in each initialiser of that contract:

```swift
let <name>: <type>
```

To declare a variable with the name `<name>` of the type `<type>` with the initial value being the result of `<expression>` (see [expressions](#expressions)), the syntax is the same, but `var` is used instead of `let`:

```swift
var <name>: <type> = <expression>
```

Examples:

```swift
var counter: Int = 0
var areWeThereYet: Bool = false
```

The value of a variable or a constant can be used in expressions once it is declared, simply by writing its name.

## Functions

Functions are self-contained blocks of code that perform a specific task, which are called using their identifier. They are defined with the keyword `func` followed by the identifier and the set of parameters and optional return type:

To declare a function with the name `<name>` returning a value of type `<type>`, taking the list of [parameters `<parameters>`](#function-parameters), optionally with [modifiers `<modifiers>`](#function-modifiers) and [attributes `<attributes>`](#function-attributes):

```swift
<attributes>
<modifiers> func <name>(<parameter-1>, <parameter-2>, ...) -> <type> {
  // statements
}
```

Some functions do not return a value:

```swift
<attributes>
<modifiers> func <name>(<parameter-1>, <parameter-2>, ...) {
  // statements
}
```

### Function attributes

Attributes annotate functions as having special properties. Currently the only example of this is `@payable`. For more information, see [payable](#payable).

### Function modifiers

In Flint all functions are `private` by default and as such can only be accessed from within the contract body. This can be changed using access modifiers:

 - `public` access enables functions to be used within their contract and exposes the function to the interface of the contract as a whole when compiled. Other contracts and users on the Ethereum network may call `public` functions directly.
 - `private` access (default and not a keyword that is explicitly set) only enables functions to be used within their contract.

Examples:

```swift
func giveOutMoney(to: Address) {
  // only callable from other contract functions
}

public func takeMoney(from: Address) {
  // can be called by Ethereum users and contracts
}
```

Smart contracts can remain in activity for a large number of years, during which a large number of state mutations can occur. To aid with reasoning, Flint functions cannot mutate smart contracts’ state by default. This helps avoid accidental state mutations when writing the code, and allows readers to easily draw their attention to the mutating functions of the smart contract.

Naturally, it is sometimes desirable to write a function that changes the state properties of its contract. This is enabled with the `mutates (...)` modifier:

Examples:

```swift
contract Counter {
  var hits: Int = 0
}

Counter :: (any) {
  // This would be a compile-time error - the function needs to be declared
  // with `mutates (...)`!
  //public func incrementA() {
  //  hits += 1
  //}

  // This can compile:
  public func incrementB() mutates (hits) {
    hits += 1
  }
}
```

### Function parameters

Functions can also take parameters which can be used within the function. These must be declared in the function signature. Flint also supports parameters that take default values, but no non-defaulted parameter may follow one that has a default value.

Each parameter has the syntax:

```swift
<modifiers> <name>: <type modifiers> <type>
```

Currently the only possible (optional) `<modifier>` is `implicit`. See [payable](#payable) for more information. The only possible (optional) `<type modifier>` is `inout`. See [inout](#structs-as-function-arguments) for more information.

Below is a function that [mutates](#function-modifiers) the dictionary of peoples' names to add the key/value pair of the caller's address and the given name. If the parameter `name` is not provided to the function call, then the default value of `"John Doe"` will be used. For more information about callers, see [caller bindings](#caller-group-variable).

```swift
contract AddressBook {
  var people: [Address: String]
}

AddressBook :: caller <- (any) {
  func remember(name: String = "John Doe") mutates (people) {
    people[caller] = name
  }
}
```

### Return values

You can optionally indicate the return type of a function with the return arrow `->`, which is followed by the return type. Inside the function, a `return` statement must be used, to return a value of the same type as the declared return type.

Example:

```swift
func hello() -> String {
  return "Hello, world!"
}
```

If the return type is omitted, the function is considered a `Void` function, and a call to it cannot be used in expressions as a value.

### Initialisers

Initialisers are special functions called to create a struct or contract instance. The syntax is slightly different:

```swift
<modifiers> init(<parameter-1>, <parameter-2>, ...) {
  // statements
}
```

The statements that can be used in initialisers are limited to "simple" statements, which means no external calls, control flow statements, etc. After an initialiser is executed, all the state properties of its containing struct or contract should have a value.

### Payable
_Only in: Contracts on Solidity_

When a user creates a transaction to call a function, they can attach Wei to send to the contract. Functions which expect Wei to be attached when called must be annotated with the `@payable` annotation, otherwise the transaction will revert when the function is called.

When adding the annotation, a parameter marked `implicit` of type `Wei` must be declared. `implicit` parameters are a mechanism to expose information from the Ethereum transaction to the developer of the smart contract, without using globally accessible variables defined by the language, such as `msg.value` in Solidity. This mechanism allows developers to name `implicit` variables themselves, and they need not remember the name of a global variable.

Functions in Flint can be marked as payable using the `@payable` attribute. The amount of Wei sent is bound to an implicit variable:

```swift
@payable
public func receiveMoney(implicit value: Wei) {
  doSomething(value)
}
```

Payable functions may have an arbitrary amount of parameters, but exactly one needs to be implicit and of a currency type. There may only be one function marked `@payable` in a contract.

### Fallback
_Only in: Contracts on Solidity_

Fallback functions are another special kind of function, with a slightly modified declaration syntax:

```swift
public fallback() {
  // statements
}
```

Fallback functions should only contain "simple" statements, just like initialisers. They are called whenever an attempt has been made to call a non-existent function of the containing contract. This may happen e.g. if the caller used an incorrect signature for the call. Oftentimes the Gas allocation for fallback execution is very low (`2300`), which only allows an [event](#events) to be logged.

## Structs

Structs in Flint are general-purpose constructs that group state and methods that can be used as self-contained blocks. They use the same syntax as defining constants and variables for properties. Structure methods are not protected as they can only be called by contract functions, and are required to be annotated `mutates (...)` if they mutate the struct's state.

### Declaration

The syntax of a struct declaration is:

```swift
struct <name> {
  // variables, constants, methods
}
```

Example:

```swift
struct Rectangle {
  var width: Int = 0
  var height: Int = 0

  func area() -> Int {
    return width * height
  }
}
```

### Instances

The declaration of a struct only describes what types of variables it contains, what their initial values are, and what methods may be used to modify or access the struct data. To create concrete instances, each with individual data values, an instance has to be created, by calling the initialiser of a struct.

```swift
<struct-name>(<initialiser-parameter-values>)
```

 > **Bug**
 >
 > Unlike for [function calls](#function-calls), it is not required to write the labels for struct initialiser parameters.

Example:

```swift
let someRectangle: Rectangle = Rectangle()
```

When an instance is created, it is initialised with its initial values – in this case a width and height of `0`. This process can also be done manually using an [initialiser](#initialisers). Defining initialisers is also required when default values are not specified for all properties of a struct. You can access the properties of the current struct with the special keyword [`self`](#self).

Example:

```swift
struct Rectangle {
  // Same definition as above with:
  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }
}
```

```swift
let bigRectangle = Rectangle(width: 400, height: 10000)
```

### Accessing properties/methods

Properties/methods of a struct instance can be accessed by writing the property/method name immediately after the instance identifier, separated by a period `.`:

```swift
<struct-instance>.<variable-name>
<struct-instance>.<constant-name>
<struct-instance>.<method-name>(<function-parameter-values>)
```

Examples:

```swift
bigRectangle.width // 400
bigRectangle.area() // evaluates to 4000000 by calling the `area` function
```

 > **Planned feature**
 >
 > In the future a `static` keyword will be added to indicate struct functions which are callable without creating a specific instance. See https://github.com/flintlang/flint/issues/419

### Structs as function arguments

Structs can be passed by reference using the `inout` type modifier. The struct is then treated as an implicit reference to the value in the caller. Any modifications made to the struct will still be visible after the function is called.

When calling a function with an `inout` parameter, the given struct instance must be prefixed with `&` to indicate it is being passed by reference.

Example:

```swift
struct S {
  var x: Int

  init(x: Int) {
    self.x = x
  }
}

func foo() {
  let s: S = S(x: 8)

  byReference(s: &s)

  // Here s.x == 10

  // This is not supported:
  //byValue(s: s)

  // Here s.x == 10 would still be true.
}

func byReference(s: inout S) {
  s.x = 10
}

// This is currently not supported:
//func byValue(s: S) {
//  s.x = 12
//}
```

 > **Planned feature**
 >
 > Passing structs by value (copying the struct into storage or memory) is a planned feature. See https://github.com/flintlang/flint/issues/133.

## Contracts

Contracts lie at the heart of Flint. They are the core building blocks of a program's code. Constants and variables can be defined inside contracts to be stored in the Ethereum network.

### Declaration

The declaration of a Flint contract consists of multiple parts. The properties are declared in a single block using the keyword `contract` followed by the contract name that will be used as the identifier.

```swift
contract <name> {
  // constant and variable declarations, event declarations
}
```

Example:

```swift
contract Bank {
  var owner: Address
  let name: String = "Bank"
  event Shutdown(reason: String)
}
```

### Type states

Flint introduces the concept of type states. Insufficient and incorrect state management in Solidity code have led to security vulnerabilities and unexpected behaviour in widely deployed smart contracts. Avoiding these vulnerabilities by the design of the language is a strong advantage.

Type states of a contract represent the possible states it can be in. At any point of time, the contract on the network can only exist in a single state. Special [`become` statements](#become-statements) can be used within functions to move the contract to a different type state.

A contract declaration may optionally include a list of its type states:

```swift
contract <name> (<type-state-1>, <type-state-2>, ...) {
  // constant and variable declarations, event declarations
}
```

Type states should be valid identifiers, starting with a capital letter.

Example:

```swift
contract Auction (Preparing, InProgress, Terminated) {}
```

Using [type state protection](#type-state-protection), it is possible to specify that only certain functions will be callable when the contract is in a given type state.

### Protection blocks

The remaining parts of a contract are its protection blocks. While traditional computer programs have an entry point (the `main` function), smart contracts do not. After a contract is deployed on the blockchain, its code does not run until an Ethereum transaction is received. Smart contracts are in fact more akin to RESTful web services presenting API endpoints. It is important to prevent unauthorised parties from calling sensitive functions.

In Flint, functions of a contract are declared within protection blocks, which restrict when the enclosed functions are allowed to be called.

There are two elements to protection blocks, the [caller group](#caller-group) and the optional [type state protection](#type-state-protection) (see [type states](#type-states) for more detail).

A minimal protection block of contract `<contract-name>` with the [caller group](#caller-group) `<caller-group>` is declared as:

```swift
<contract-name> :: (<caller-group>) {
  // functions
}
```

The caller can optionally be captured into a variable (see [caller group variable](#caller-group-variable)):

```swift
<contract-name> :: <variable> <- (<caller-group>) {
  // functions
}
```

The protection block can optionally also check that the contract is in a given [type state](#type-states) (see [type state protection](#type-state-protection)):

```swift
<contract-name> @(<type-state>) :: (<caller-group>) {
  // functions
}
```

Alternatively, protection blocks can be declared within the contract declaration part with the same syntax but using `self` instead of the contract name:

```swift
contract <contract-name> {
  // ...
  self :: (<caller-group>) {
    // ...
  }
}
```

Solidity uses function modifiers to insert dynamic checks in functions, which can for instance abort unauthorised calls. However, it is easy to forget to specify these checks, as the language does not require programmers to write them.

Having a language construct which protects functions from invalid calls could require programmers to systematically think about which parties should be able to call the functions they are about to define.

In Flint, functions of a contract are declared within protection blocks, which protect the functions from invalid access.

#### Caller group

Caller groups consist of a list of caller members enclosed in parentheses. These caller members may be identified using multiple mechanisms, as listed below. Functions inside protection blocks can only be called by an Ethereum address (the "caller" address) that satisfies at least one of the caller members of that protection block.

| Name | Flint type | Callable when |
| --- | --- | --- |
| Predicate function | `Address -> Bool` | The function is called with the caller as input, must return `true`. |
| 0-ary function | `() -> Address` | The returned address must match the caller address. |
| State property (single address) | `Address` | The address property must match the caller address. |
| State property (list of addresses) | `[Address]` or `Address[n]` | The caller address must be contained within the list of addresses. |
| State property (dictionary of addresses) | `[T: Address]` | The caller address must be contained with in the values of the dictionary. |
| Any | `any` | Always. |

> _Move-specific:_ Note that only state properties and `any` work in caller protection blocks due to target limitations. It will be expanded once collections are implemented in the underlying MoveIR

Examples:

```swift
contract Bank {
  let owner: Address
  var managers: [Address]
}

Bank :: (owner, managers) {
  // ...
}

contract Lottery {}

Lottery :: (lucky) {
  func lucky(address: Address) -> Bool {
    // return true or false
  }
}
```

The address of the caller of a function is unforgeable. It is not possible to impersonate another user, as a consequence of both Ethereum’s mechanism which generates public addresses from private keys and MoveIR's transaction system. On Ethereum, transactions are signed using a private key, and determine the public key of the caller. Stealing a caller capability would hence require stealing a private key. The recommended way for Ethereum users to transfer their ability to call functions is to either change the backing address of the caller capability they have (the smart contract must have a function which allows this), or to securely send their private key to the new owner, outside of the Ethereum platform.

Calls to Flint functions are validated both at compile-time and runtime, with runtime checks only being added where necessary.

#### Caller group variable

It is sometimes useful to know which address initiated the current transaction, in addition to verifying it with caller groups. This is possible with the optional caller group variable.

```swift
<contract-name> :: <variable> <- (<caller-group>) {
  // functions
}
```

Example:

```swift
contract AddressBook {
  var book: [Address: String] = [:]
}

AddressBook :: address <- (any) {
  public func remember(name: String) {
    book[address] = name
  }
}
```

#### Type state protection

A protection block may also be used to ensure that certain functions are only called when the contract is in a given type state.

```swift
<contract-name> @(<type-state>) :: (<caller-group>) {
  // functions
}
```

Example:

```swift
contract Poll(Open, CountingVotes, Result) {
  // ...
}

Poll @(Open) :: (any) {
  public func voteFor(option: String) {
    // ...
  }
}
```

In this example the `voteFor` function could only be called when the `Poll` was in the `Open` state.

#### Static checking

In a Flint function, if a function call to another Flint function is performed, the compiler checks that the caller meets the caller protection.

Consider the following example:

```swift
Bank :: (any) {
  func foo() {
    // Error: Protection "any" cannot be used to perform a call to a
    // function for "manager"
    bar()
  }
}

Bank :: (manager) {
  func bar() {}
}
```

Within the context of `foo`, the caller is regarded as `any`. It is not certain that the caller also satisfies the `manager` protection, so the compiler rejects the call.

#### Dynamic checking

In the above example, it is still possible for `foo` to satisfy the protections of the function `bar`. For such cases, two additional language constructs exist:

 - `try? bar()`: The function `bar` is called if, at runtime, the protections are satisfied (i.e. the caller satisfies the caller protection and the state of the contract satisfies the type state protection). The expression `try? bar()` returns a boolean if successful.
 - `try! bar()`: If at runtime `bar` protections are not satisfied an exception is thrown (reverting the transaction) and the function is not executed.

#### Multiple protections

A contract behaviour declaration can be restricted by multiple caller protections. Consider the following contract behavior declaration:

```swift
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {}
}
```

The function `forManagerOrCustomers` can be called either by the manager, or by any of the accounts registered in the bank.

Calls to functions of multiple protections are accepted if **each** of the protections of the enclosing function are compatible with **any** of the target function's protections.

Consider the following examples:

```swift
// Insufficient protections
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Error: "accounts" is not compatible with "manager"
    forManager()
  }
}

Bank :: (manager) {
  func forManager() {}
}
```

```swift
// Sufficient protections
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Valid: "manager" is compatible with "manager", and "accounts" is
    // compatible with "accounts"
    forManagerOrCustomers2()
  }
}

Bank :: (accounts, manager) {
  func forManagerOrCustomers2() {}
}
```

```swift
// `any` is compatible with any caller protection
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Valid: "manager" is compatible with "manager" (and "any", too), and "accounts"
    // is compatible with "any"
    forManagerOrCustomers2()
  }
}

// The caller protection "manager" has no effect: "any" is compatible with any caller protection
Bank :: (manager, any) {
  func forManagerOrCustomers2() {}
}
```

### Visibility Modifiers

Variables declared in the contract can have modifiers in front of their declaration which control the automatic synthesis of variable accessors and mutators. By the nature of smart contracts all storage is visible already, but providing accessors makes that process easier.

 - `public` access synthesises an accessor and a mutator so that the storage variable can be viewed and changed by anyone.
 - `visible` access synthesises an accessor to the storage variable which allows it to be viewed by anyone.
 - `private` access means that nothing is synthesised (but both accessors and mutators can still be manually specified).

An accessor, if synthesised for variable `<name>` or type `<type>`, has the signature `public func get<Name>() -> <type>`. A mutator, if synthesised for the same variable, has the signature `public func set<Name>(to: <type>) mutates (<Name>)`.

Example:

```swift
public var value: Int
visible var name: String = "Bank"
```

The above declarations cause these functions to be synthesised:

```swift
public func getValue() -> Int
public func setValue(to: Int)
public func getName() -> String
```

### Events
_Only on: Solidity_

JavaScript applications can listen to events emitted by an Ethereum smart contract.

In Flint, events are declared in contract declarations. They use a similar syntax to functions, except using the keyword `event`.

```swift
event <event-name>(<event-parameter-1>, <event-parameter-2>, ...)
```

Like functions, some of the parameters can have default values, but these must be declared at the end of the parameter list.

Events can then be emitted using the keyword `emit` followed by an event call. An event call is similar to a function call (parameters must be provided in order, and they must have the correct label and type; if any optional parameters are omitted, their default value will be used automatically).

```swift
contract Bank {
  var balances: [Address: Int]
  event CompletedTransfer(origin: Address, destination: Address, amount: Int)
}

Bank :: caller <- (any) {
  func transfer(to: Address, value: Int) mutates(balances) {
    // Note the following 2 lines are unsafe!
    balances[caller] -= value
    balances[to] += value

    // A JavaScript client could listen for this event:
    emit CompletedTransfer(origin: caller, destination: to, amount: value)
  }
}
```

## Traits

Flint has the concept of 'traits', based in part on [traits in the Rust language](https://doc.rust-lang.org/rust-by-example/trait.html). Traits describe the partial behaviour of the contracts or structs which conform to them. For contracts, traits constitute a collection of functions, function signatures in protection blocks, and events. For structs, traits only constitute a collection of functions and function signatures.

Contracts or structs can conform to multiple traits. The Flint compiler enforces the implementation of function signatures in the trait and allows usage of the functions declared in them. Traits allow a level of abstraction and code reuse for contracts and structs.

 > **Planned feature**
 >
 > In the future, the Flint standard library will include traits providing common functionality to contracts (`Ownable`, `Burnable`, `MultiSig`, `Pausable`, `ERC20`, `ERC721`, etc.) and structs (`Transferable`, `RawValued`, `Describable` etc.). It will also form the basis for allowing end users to access compiler level guarantees and restrictions as in [assets](#assets) and Numerics.

### Struct traits

Traits can be declared for structs using the syntax:

```swift
struct trait <trait-name> {
  // trait members
}
```

Structs can conform to struct traits using the syntax:

```swift
struct <struct-name>: <trait-1>, <trait-2>, ... {
  // ...
}
```

Struct traits can contain functions, function signatures, initialisers, and initialiser signatures. A function or initialiser signature simply declares the name (for a function) and parameter types, without providing the actual code implementation.

Example:

In this example we define an `Animal` struct trait. The `Person` struct then conforms to the `Animal` trait.

```swift
struct trait Animal {
  // Must have an empty and named initialiser.
  public init()
  public init(name: String)

  // These are signatures that conforming structures must implement
  // access properties of the structure.
  func isNamed() -> Bool
  public func name() -> String
  public func noise() -> String

  // This is a pre-implemented function using the functions already in the trait.
  public func speak() -> String {
    if isNamed() {
      return name()
    }
    else {
      return noise()
    }
  }
}

struct Person: Animal {
  let name: String

  public init() {
    self.name = "John Doe"
  }
  public init(name: String) {
    self.name = name
  }

  // People always have a name, it's just not always known.
  func isNamed() -> Bool {
    return true
  }

  // These access the properties of the struct.
  public func name() -> String {
    return self.name
  }

  public func noise() -> String {
    return "Huh?"
  }

  // Person can also have functions in addition to Animal.
  public func greet() -> String {
    return "Hi"
  }
}
```

### Contract traits

Traits can be declared for contracts using the syntax:

```swift
contract trait <trait-name> {
  // trait members
}
```

Contracts can conform to contract traits using the following syntax for their declaration part:

```swift
contract <contract-name>: <trait-1>, <trait-2>, ... {
  // ...
}
```

Contract traits can contain anonymous contract behaviour declarations containing functions, function signatures, and events.

Example:

In this example, we define `Ownable`, which declares a contract as something that can be owned and transferred. The `Ownable` trait is then used by the `ToyWallet` contract allowing the use of methods in `Ownable`. This demonstrates how we can expose contract properties:

```swift
contract trait Ownable {
  event OwnershipRenounced(previousOwner: Address)
  event OwnershipTransfered(previousOwner: Address, newOwner: Address)

  self :: (any) {
    public func getOwner() -> Address
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
  // Skipping initialiser not relevant for this example
}

ToyWallet :: (getOwner) {
  func setOwner(newOwner: Address){
    self.owner = newOwner
  }
}
```

### External traits

External traits allow interfacing with contracts (and resources) from the target language. Traits can be declared for external contracts using the syntax:

```swift
<attributes>
external trait <trait-name> {
  // trait members
}
```

See the [specifying the interface of external calls](#specifying-the-interface) section for more information.

### Polymorphic self

`Self` (note the capital 'S') is a special type available only in struct and contract traits. It refers to the type that implements the current trait, but not any other type that conforms to that trait. This is particularly useful when providing default implementations for functions in a trait. See [assets](#assets) for an example in the standard library.

Example without `Self`:

```swift
struct trait Unit {
  func add(source: inout Unit)
}

struct Metre: Unit {
  var length: Int = 0
  func add(source: inout Unit) {
    length += source.length // compilation error here
  }
}
```

In the above example, we only want to be able to add metres to metres. Accessing `source.length` is invalid, because `length` is only declared in `Metre`. Instead, using `Self`:

```swift
struct trait Unit {
  func add(source: inout Self)
}

struct Metre: Unit {
  var length: Int = 0
  func add(source: inout Metre) mutates (length) {
    length += source.length
  }
}

struct Litre: Unit {
  var volume: Int = 0
  func add(source: inout Litre) mutates (volume) {
    volume += source.volume
  }
}
```

In this example, both `Metre` and `Litre` are valid. But it would a call like `aMetreInstance.add(source: &aLitreInstance)` would cause a compile-time error.

## Expressions

Expressions are at the core of any computation done in Flint code. Evaluating an expression results in a single value of a given type. Expressions can be nested to arbitrary layers.

The expressions available in Flint are:

| Name | Syntax | Description |
| --- | --- | --- |
| Literal | `1`, `"hello"`, `false`, etc. | Constant value; see [literals](#literals). |
| Range | `<expr-1>..<<expr-2>`, `<expr-1>...<expr-2>` | See [ranges](#range-types). |
| Binary expression | `<expr-1> <op> <expr-2>` | A binary operation `<op>` applied to the expressions `<expr-1>` and `<expr-2>`; see [operators](#operators). |
| Struct reference | `&<expr>` | See [structs as function arguments](#structs-as-function-arguments). |
| Function call | `<function-name>(<param-1>: <expr-1>, <param-2>: <expr-2>, ...)` | Call to the function `<function-name>` with the results of the given expressions `<expr-1,2,...>` as parameters. See [function calls](#function-calls). |
| Dot access | `<expr-1>.<field>` | Access to the `<field>` field (variable, constant, function) or the result of `<expr-1>`. |
| Index / key access | `<expr-1>[<expr-2>]` | Access to the given key of a list or dictionary. _(Only on Solidity)_ |
| External call | `call <external-contract>.<function-name>(<param-1>: <expr-1>, <param-2>: <expr-2>, ...)` | Call to the function of an external contract; see [external calls](#external-calls). |
| Type cast | `<expr> as! <type>` | Forced cast of the result of `<expr>` to `<type>`; see [casting to and from Solidity types](#casting-to-and-from-solidity-types). |
| Attempt | `try? <call>`, `try! <call>` | Attempt to call a function in a different protection block, see [dynamic checking](#dynamic-checking). |

### Function calls

Functions can then be called from within a contract protection block with the same identifier. The call arguments must be provided in the same order as the one they are declared in (in the function signature), and they must be labeled accordingly (the exception for this is [struct initialisers](#instances)). If any of the optional parameters are not provided, then their default values are used automatically.


````swift
@payable
public func apply(name: String, implicit Fee: Wei ) mutates (balances) {
  bankroll(applicant: caller, amount: stake)
  ...
}

func bankroll (applicant: Address, amount: Int ) mutates (balances) {
  balances[applicant] = amount
}
````

## Literals

Literals represent fixed values in the source code that can be assigned to constants and variables.

### Integer literals

Integer literals (Flint type `Int`) can be written as decimal numbers. The size of the `Int` type in Flint is 256 bits (32 bytes), so the highest allowed integer is quite large (`2^256 - 1`, more than 76 decimal degits). Underscores can be used to separate digits of integer literals.

Examples:

```swift
42
2019
1_22_333
1_000_000_000_000_000_000_000_000
```

### Address literals

Address literals (Flint type `Address`) are written as 40 hexadecimal digits prefixed by a `0x`. Addresses are an important concept in Ethereum, referring to other contracts and accounts. Underscores can be used to separate digits of address literals.

Examples:

```swift
0x1234123412341234123412341234123412341234
0x0CB1DB10A4820BD10823AE0101F02198CAFEBABE
0xCAFEBABE_CAFEBABE_CAFEBABE_CAFEBABE_CAFEBABE
```

### Boolean literals

Boolean literals (Flint type `Bool`) are simply `true` and `false`.

### String literals
_Only on: Solidity `--skip-verifier`_

String literals (Flint type `String`) are sets of characters enclosed in double quotes `"..."`.

Examples:

```swift
""
"hello"
"This is a sentence."
```

 > **Bug**
 >
 > Due to the fact that `Strings` are currently stored in a single EVM memory slot, they cannot be longer than 32 bytes. See https://github.com/flintrocks/flint/issues/133.

### List literals
_Only on: Solidity_

List literals (Flint type `[T]` or `T[n]` for some Flint type `T`) currently only include the empty list `[]`.

 > **Planned feature**
 >
 > In the future, Flint will have non-empty list literals written as `[x, y, z, ...]` where `x`, `y`, `z`, etc. are literals of type `T`. See https://github.com/flintlang/flint/issues/420.

### Dictionary literals
_Only on: Solidity_

Dictionary literals (Flint type `[T: U]` for some Flint types `T` and `U`) currently only include the empty dictionary `[:]`.

 > **Planned feature**
 >
 > In the future, Flint will have non-empty dictionary literals written as `[x: a, y: b, z: c, ...]` where `x`, `y`, `z`, etc. are literals of type `T` and `a`, `b`, `c`, etc. are literals of type `U`. See https://github.com/flintlang/flint/issues/420.

### Self

The special keyword `self` refers to the current struct instance or contract containing the current function.

## Operators

An operator is a special symbol used to check, change, or combine values. Flint supports common Swift operators and attempts to eliminate common coding errors.

### Arithmetic operators

Flint supports the following arithmetic operators for `Int` expressions:

 - `+` - Addition
 - `-` - Subtraction
 - `*` - Multiplication
 - `/` - Division
 - `**` - Exponentiation

Examples:

```swift
1 + 2 // equals 3
5 - 3 // equals 2
2 * 3 // equals 6
10 / 2 // equals 5
2 ** 3 // equals 8
```

Flint has unique safe arithmetic. The `+`, `-`, `*` and `**` operators throw an exception and abort execution of the smart contract when an overflow occurs. The `/` operator implements integer division. No underflows can occur as floating-point numbers are not supported yet. The performance overhead of the safe operators is low.

In rare cases, allowing overflows is the intended behaviour. Flint also supports
overflowing operators, which will not crash on overflow:

 - `&+` - Unsafe addition
 - `&-` - Unsafe subtraction
 - `&*` - Unsafe multiplication

> _Move-specific:_ Due to MoveIR not allowing unsafe operations, unsafe operators are translated into safe operators, so act like `+`, `-`, and `*`

### Boolean operators

These operators all result in `Bool`:

 - `==` - Equal to
 - `!=` - Not equal to
 - `||` - Logical or
 - `&&` - Logical and
 - `<` - Less than
 - `<=` - Less than or equal to
 - `>` - Greater than
 - `>=` - Greater than or equal to

Examples:

```swift
1 == 1 // true because 1 is equal to 1
2 != 1 // true because 2 is not equal to 1
2 > 1 // true because 2 is greater than 1
1 < 2 // true because 1 is less than 2
1 >= 1 // true because 1 is greater than or equal to 1
2 <= 1 // false because 2 is not less than or equal to 1
true || false // true because one of true and false is true
true && false // false because one of true and false is false
```

## Statements

Statements control the execution of code in a function, enable looping, conditional behaviour, and more.

### Variable/constant declaration and assignment

Declaration of variables and constants is a statement (see [variables and constants](#constants-and-variables)). Syntax:

```swift
let <name>: <type> = <expression>
let <name>: <type>
var <name>: <type> = <expression>
var <name>: <type>
```

#### Compound assignment

Flint also provides compound assignment statements that combine assignment (`=`) with another operator. Namely:

 - `+=` Compound addition
 - `-=` Compound subtraction
 - `*=` Compound times
 - `/=` Compound division

Example:

```swift
x += 5
// is equivalent to:
x = x + 5
```

### Loops

`for-in` loops can be used to iterate over sequence. Currently this supports lists, dictionary values and [ranges](#range-types). Syntax:

```swift
for let <variable-name>: <type> in <sequence> {
  // ...
}
```

Alternatively, the iteration value can be a variable, so it can be modified, though modifications are reset on each loop:

```swift
for var <variable-name>: <type> in <sequence> {
  // ...
}
```

Example:

Assuming a variable-length list `names` (of type `[String]`), it can be iterated over, binding the current iteration value to the constant `name` of type `String`, using:

```swift
for let name: String in names {
  // do something with `name`
}
```

### Conditionals

The `if` statement allows executing different code based on the result of a condition (of Flint type `Bool`). Syntax:

```swift
if <condition> {
  // ...
}
```

Example:

```swift
if x == 2 {
  // ...
}
```

#### Else clauses

The `if` statement can also provide an alternative set of statements known as an `else` clause which gets executed when the condition evaluates to `false`. Syntax:

```swift
if <condition> {
  // ...
} else {
  // ...
}
```

Example:

```swift
if x == 2 {
  // ...
} else {
  // ,,,
}
```

### Become statements
_Only on: Contracts_

The `become` statement can be used to change the type state (see [type states](#type-states)) of the current contract. The execution of code is terminated after a `become` statement is executed, and the contract will then transition to the specified type state. Syntax:

```swift
become <type-state>
```

Example:

```swift
contract Semaphore(Red, Green) {}

Semaphore @(Red) :: (any) {
  public func wait() {
    become Green
  }
}

Semaphore @(Green) :: (any) {
  public func wait() {
    become Red
  }
}
```

### Return statements

A `return` statement can be used to provide the output value of a function with a declared return type (see [functions](#functions)). Syntax:

```swift
return <expression>
```

Example:

```swift
Semaphore @(Red) :: (any) {
  public func countWaitingCars() -> Int {
    return 200
  }
}
```

### Do-catch blocks

`do-catch` blocks can be used to handle errors in execution in a controlled manner. Currently, the only supported error is an external call error (see [external calls](#external-calls)). Syntax:

```swift
do {
  // ...
} catch is ExternalCallError {
  // ...
}
```

## External calls

External calls refer to a Flint contract calling the functions of other contracts deployed on the Ethereum network. They also allow money to be transferred from Flint contracts to other accounts and contracts, enabling full participation in the Ethereum network.

However, external contracts include their own set of possible risks and security considerations. When writing code that interacts with external contracts, it is important to keep in mind that:

 1. External contracts may execute arbitrary code when called – although the called contract does not have access to the memory or state storage of the calling (Flint) contract, it may still cause problems. In particular, care should be taken when handling the output returned from an external contract. Additionally, the external contract may call arbitrary function of the calling (Flint) contract, potentially resulting in a re-entrancy attack.
 2. Interfaces of external contracts may be incorrectly specified – since the EVM does not retain any type information, it is up to the programmer to correctly specify the functions available on an external contract. If the interface is specified incorrectly, this may lead to the wrong function being called and money being lost.

 > **Planned feature**
 >
 > In the future, external calls will include automatic re-entrancy attack protection, where no function of a Flint contract will be callable during the execution of an external call. See https://github.com/flintrocks/flint/issues/74.

### Specifying the interface

The interface of an external contract is specified using a special `external` trait. Syntax:

```swift
<attributes>
external trait <trait-name> {
  // functions
}
```

The functions declared inside an external trait may not include any modifiers, and their parameters and return types (if used) must be specified using [External types](#external-types) on Ethereum. On Move, they may return Move structs.

Currently, deploying contracts from within Flint code is not supported, so neither initialisers nor fallbacks can be provided in external traits.

Example:

```swift
external trait ExternalBank {
  @payable
  func pay() -> int256
  func withdraw(amount: int256) -> int256
}
```

#### External Trait Attributes

External trait attributes are a way of providing compiler directives so Flint can understand how to handle the external traits you've declarared in the produced output. They are used by the target's code generation, and thus are target-specific. Currently, the evm target doesn't have any trait attributes. Move uses the following to allow you to provide enough information about how to handle your external traits:

```swift
@module(address: 0x0)  // Provide the address of the module (the address of the resource is provided as in Ethereum)
@data                  // The following trait is for a Move struct, not a contract
@resource              // Used with @data, the following external struct is a resource
```

### Creating an instance

To work with an external contract in a type-safe manner, every external trait automatically creates an implicit constructor, which takes a single `address` parameter.

```swift
<external-trait-name>(address: <address>)
```

Example:

```swift
external trait Ext {}
contract X {}

X :: (any) {
  public func callback(externalAddress: Address) {
    let extInstance = Ext(address: externalAddress)
  }
}
```

### Calling functions

Functions of an external contract instance may be called using the keyword `call`. Flint provides two modes of operation for external calls, and they are semantically similar to `try` in Swift.

```swift
call <contract>.<function-name>(<parameters>)
call! <contract>.<function-name>(<parameters>)
```

The forced mode is invoked with the syntax `call!` (note the exclamation mark). If the external call fails for any reason (e.g. the external contract runs out of gas), the entire transaction will revert.

```swift
X :: (any) {
  public func callback(externalAddress: Address) {
    let extInstance = Ext(address: externalAddress)
    call! extInstance.someFunction()
  }
}
```

The default (safe) mode is invoked with the syntax `call` (without the exclamation mark). Any default call must be inside a `do-catch` block, and a failure in the external call will cause the code in the `catch` block to be executed.

```swift
X :: (any) {
  public func callback(externalAddress: Address) {
    let extInstance = Ext(address: externalAddress)
    do {
      call extInstance.someFunction()
    } catch is ExternalCallError {
      // handle the error here
    }
  }
}
```

 > **Planned feature**
 >
 > A third mode will be available in the future, `call?`. It will return an `Optional` type, like in Swift, intended to be used with the (also planned) `if let ...` construct. See https://github.com/flintrocks/flint/issues/140.

### Specifying hyper-parameters

In addition to function parameters, there are two more "hyper-parameters" that need to be set when performing an external call.

The `gas` hyper-parameter (defaults to `2300`) with type `Int` specifies how much Gas is allocated for the external call. Executing any code in EVM costs Gas and so the more Gas is provided, the more work can be done in a contract. The default amount, `2300`, is enough to emit a single event (at the time of writing).

The `value` hyper-parameter (defaults to `0`) with type `Wei` specifies how much, if any, Wei is attached to the external call. Providing a non-zero amount causes money to be transferred from the calling (Flint) contract to the external contract. `value` must be specified if and only if calling a function marked as `@payable`.

To specify `gas` and/or `value` for an external call, the syntax is:

```swift
call(<hyper-parameters>) <contract>.<function-name>(<parameters>)
call(<hyper-parameters>)! <contract>.<function-name>(<parameters>)
```

Example:

```swift
X :: (any) {
  public func callback(externalAddress: Address) {
    let extInstance = Ext(address: externalAddress)
    call(gas: 10000)! extInstance.someLongFunction()
    call(value: Wei(unsafeRawValue: 100))! extInstance.someExpensiveFunction()
    call(gas: 10000, value: Wei(unsafeRawValue: 100))! extInstance.someLongExpensiveFunction()
  }
}
```

### Casting to and from Solidity types

Since the types of external contract function parameters and return values are specified using [Solidity types](#solidity-types), values must be converted before they are used for an external call. This is facilitated using the type casting expression.

Example:

```swift
X :: (any) {
  public func callback(externalAddress: Address) {
    let extInstance = Ext(address: externalAddress)
    var flintInt: Int = 1
    call! extInstance.someFunctionTakingAnInt(someParameter: flintInt as! int256)

    flintInt = (call! extInstance.someReturningFunction()) as! Int
  }
}
```

The forced cast (`as!`) expression converts Flint types to Solidity types and vice versa, after performing some basic runtime checks to make sure that the original value fits into the target value, since Solidity supports integer types of smaller sizes than the Flint default of 256 bits. An error results in the transaction being reverted.

 > **Planned feature**
 >
 > In the future, casting failures will be possible to handle using `do-catch` blocks or an optional cast mode `as?`.

## Enumerations

An enumeration defines a common group of values with the same type and enables working with those values in a type-safe way within Flint code. The syntax is:

```swift
enum <name>: <associated-type> {
  case <case-name>
  // additional cases...
}
```

Example:

```swift
enum CompassPoint: Int {
  case north
  case south
  case east
  case west
}
```

The values defined in an enumeration (such as `north`, `south`, `east` and `west`) are its enumeration cases. Each enumeration defines a new user-defined type. To access a given case, dot syntax is used:

```swift
<enum-name>.<case-name>
```

Example:

```swift
var direction: CompassPoint
direction = CompassPoint.north
```

### Associated Values

You can assign raw values to enumeration cases. The values need to match the type associated with the enumeration. Flint will also try to infer the raw value of cases by default based on the raw value of the last declared enumeration case.

Example:

```swift
enum Numbers: Int {
  case one = 1
  case two = 2
  case three // Numbers.three == 3
  case four // Numbers.four == 4
}
```

# Standard library

## Wei
_Only on: Solidity_

Numerous attacks targeting smart contracts, such as ones relating to re-entrancy calls (see TheDAO), allowed hackers to steal a contract’s Ether. Some of these happened because smart contracts encoded Ether values as integers, making it easy to make mistakes when performing Ether transfers between variables, or to forget to record Ether arriving or leaving the smart contract.

Flint supports special safe operations when handling assets, such as Wei (the smallest unit of Ether). They help ensure the contract's state consistently represents its Wei value, preventing attacks such as TheDAO.

A simple use of Wei:

```swift
contract Wallet {
  var owner: Address
  var contents: Wei = Wei(unsafeRawValue: 0)
}

Wallet :: caller <- (any) {
  public init() {
    owner = caller
  }

  @payable
  public func deposit(implicit value: Wei) mutates (contents) {
    // Record the Wei received into the contents state property.
    // Value is passed by reference.
    contents.transfer(source: &value)
  }
}

Wallet :: (owner) {
  public func withdraw(value: Int) mutates (contents) {
    // Transfer an amount of Wei into a local variable. This
    // removes Wei from the contents state property.
    var w: Wei = Wei(source: &contents, amount: value)

    // Send Wei to the owner's Ethereum address.
    send(address: owner, value: &w)
  }

  public func getContents() -> Int {
    return contents.getRawValue()
  }
}
```

Another example which uses Wei is the Bank example.

```swift
contract Wallet {
  var beneficiaries: [Address: Wei]
  var weights: [Address: Int]
  var bonus: Wei
  var owner: Address
}

Wallet :: (any) {
  @payable
  func receiveBonus(implicit newBonus: inout Wei) mutates (contents) {
    bonus.transfer(source: &newBonus)
  }
}

Wallet :: (owner) {
  func distribute(amount: Int) mutates (contents) {
    let beneficiaryBonus = bonus.getRawValue() / beneficiaries.count
    for let person: Address in beneficiaries {
      var allocation = Wei(source: &balance, amount: amount * weights[person])
      allocation.transfer(source: &bonus, amount: beneficiaryBonus)
      send(address: beneficiaries[i], value: &allocation)
    }
  }
}
```

## Assets
Wei is an example of an asset, and it is a struct conforming to the `struct trait Asset`, available in the standard library. It is possible to declare custom structs which will behave like assets:

```swift
struct MyWei : Asset {
  var rawValue: Int = 0

  init(unsafeRawValue: Int) {
    self.rawValue = unsafeRawValue
  }

  init(source: inout MyWei, amount: Int) {
    transfer(source: &source, amount: amount)
  }

  init(source: inout MyWei) {
    let amount: Int = source.getRawValue()
    transfer(source: &source, amount: amount)
  }

  func setRawValue(value: Int) -> Int
      mutates (rawValue) {
    rawValue = value
    return rawValue
  }

  func getRawValue() -> Int {
    return rawValue
  }
}
```

The `transfer` functions are declared in the `Asset` trait and are inherited automatically. For the time being, traits do not support default implementations for initialisers or variables, so custom assets have to include the code above. Struct traits also do not support variables as part of the conformance, which is why `setRawValue` and `getRawValue` are required.

## Global Functions

Global functions in the standard library are special function which can be called from any contract, struct, or contract group.

### Assertions

Assertions are checks that happen at runtime. They are used to ensure an essential condition is satisfied before executing any further code. If the boolean condition evaluates to `true` then the execution continues as usual. Otherwise the transaction is reverted.

```swift
assert(<expr>)
```

Example:

```swift
assert(x == 2)
```

In essence an assertion is a shorthand for the longer:

```swift
if x == 2 {
  fatalError()
}
```

### Fatal error

`fatalError()` is a function exposed that reverts a transaction when called. This means that any contract storage changes are rolledback and no values are returned.

### Send
_Only on: Solidity_

`send(address: Address, value: inout Wei)` sends the `value` Wei to the Ethereum address `address`, and clears the contents of `value`. It is a simpler way to perform a money transfer compared to [external calls](#external-calls), but does not allow hyper-parameters to be specified.
