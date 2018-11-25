# Language Guide

:+1::tada: First off, thanks for the interest in Flint! :tada::+1:

Even though the Ethereum platform requires smart contract programmers to ensure the correct behaviour of their program before deployment, it has not seen a language designed with safety in mind. Solidity and others do not tailor for Ethereum’s unique programming model and instead, mimic existing popular languages like JavaScript, Python, or C, without providing additional safety mechanisms.

Flint changes that, as a new programming language built for easily writing safe Ethereum smart
contracts. Flint is approachable to existing and new Ethereum developers, and presents a
variety of security features.

- **Setup**
  - [Installation](#installation)
  - [Syntax Highlighting](#syntax-highlighting)
  - [Compilation](#compilation)
- **Programming In Flint**
  - [Constants and Variables](#constants-and-variables)
  - [Literals](#literals)
  - [Comments](#comments)
  - [Operators](#operators)
  - [Contracts](#contracts)
  - [Control Flow](#control-flow)
  - [Functions](#functions)
  - [Types](#types)
  - [Range](#range)
  - [Structures](#structures)
  - [Enumerations](#enumerations)
- **Flint Specific Features**
  - [Safe Arithmetic](#safe-arithmetic)
  - [Assets](#assets)
  - [Protection Blocks](#protection-blocks)
  - [Payable](#payable)
  - [Events](#events)
  - [Type States](#type-states)
  - [Traits](#traits)
- **Standard Library**
  - [Assertions](#assertions)
- **Examples**
  - [Example](#examples)


---
# Setup
---

## Installation
### Docker
The Flint compiler and its dependencies can be installed using Docker:
```
Docker pull franklinsch/flint
docker run -i -t franklinsch/flint
```
Example smart contracts are available in `/flint/examples/valid/`.

## Binary Packages and Building from Source
### Dependencies

#### Swift
The Flint compiler is written in Swift, and requires the Swift compiler to be installed, either by:
- Mac only: Installing Xcode (recommended)
- Mac/Linux: Using `swiftenv`
  1. Install swiftenv: `brew install kylef/formulae/swiftenv`
  2. Run `swiftenv install 4.1`

#### Solc
Flint also requires the Solidity compiler to be installed:

**Mac**
```
brew update
brew upgrade
brew tap ethereum/ethereum
brew install solidity
```
**Linux**
```
sudo add-apt-repository ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install solc
```

### Binary Packages
Flint is compatible on macOS and Linux platforms, and can be installed by downloading a built binary directly.

The latest releases are available at https://github.com/flintlang/flint/releases.


### Building From Source
The best way to start contributing to the Flint compiler, `flintc`, is to clone the GitHub repository and build the project from source.

Once you have the `swift` command line tool installed, you can build `flintc`.
```
git clone https://github.com/flintlang/flint.git
cd flint
make
```
The built binary is available at `.build/debug/flintc`.

Add `flintc` to your PATH using:
```
export PATH=$PATH:.build/debug/flintc
```

**Using Xcode**

If you have Xcode on your Mac, you can use Xcode to contribute to the compiler.

You can generate an Xcode project using:
```
swift package generate-xcodeproj
open flintc.xcodeproj
```

---
## Syntax Highlighting
Syntax highlighting for Flint source files can be obtained through several editors, including:
### Vim
By running the following command in the flint repository vim will now have syntax highlighting.
```
ditto utils/vim ~/.vim
```
### Atom
The `language-flint` package can be downloaded to have syntax highlighting for flint files.

---
## Compilation
Flint compiles to EVM bytecode via YUL IR using the Solidity compiler, which can be deployed to the Ethereum blockchain using a standard client, or Truffle.

For testing purposes, the recommended way of running a contract is by using the Remix IDE.

### Using Remix
Remix is an online IDE for testing Solidity smart contracts. Flint contracts can also be tested in Remix, by compiling Flint to Solidity.

In this example, we are going to compile and run the `Counter` contract, available to download [here](https://github.com/flintlang/flint/blob/master/examples/valid/counter.flint).

#### Compiling
A Flint source file named `counter.flint` containing a contract `Counter` can be compiled to a Solidity file using:
```
flintc main.flint --emit-ir
```
You can view the generated code, embedded as a Solidity program:
```
cat bin/main/Counter.sol
```
Example smart contracts are available in the repository, under `examples/valid`.

#### Interacting with contract in Remix
To run the generated Solidity file on Remix:

1. Copy the contents of  `bin/main/Counter.sol` and paste the code in Remix.

1. Press the red Create button under the Run tab in the right sidebar.

1. You should now see your deployed contract below. Click on the copy button on the right of `Counter` to copy the contract's address.

1. Select from the dropdown right above the Create button and select `_InterfaceMyContract`.

1. Paste in the contract's address in the "Load contract from Address" field, and press the At Address button.

1. You should now see the public functions declared by your contract (`getValue`, `set`, and `increment`). Red buttons indicate the functions are mutating, whereas blue indicated non-mutating.

You should now be able to call the contract's functions.

---
# Programming In Flint
---
A smart contract’s state is represented by its fields, or state properties. Its behaviour is characterised by its functions, which can mutate the contract’s state. Public functions can be called by external Ethereum users.
Flint’s syntax is focused on allowing programmers to write and reason about smart contracts easily. Providing an intuitive and familiar syntax is essential for programmers to express their smart contract naturally. As the source code of a smart contract is publicly available, it should be easily understandable by its readers. The syntax is inspired by the Swift Programming
Language’s syntax.

When developing Flint, we focused on the novel features aimed at smart contract security.
For this reason, some features which developers might expect from a programming language
and its compiler such as recursive data types or type inference have not yet been implemented
in the compiler.

## Constants and Variables
Constants and Variables associate a name with a value of a particular type. The value of a constant can't be changed once it's set, whereas a variable can be set to a different value in the future.

Variables can be state properties - public contract specific data stored in EVM Storage - or local variables - transaction specific data stored temporarily in EVM Memory.

### Declaring Constants and Variables
You declare constants with the `let` keyword and variables with the `var` keyword.

Flint is a typed language and as such every variable and constant should be annotated with a type. A type annotation places a colon after the name. To see what types are built-in see [Types](#types).

```swift
let maxValues: Int = 10
var currentValue: Int = 0
```

A colon can be thought of as "... of type ...", so the code above can be read as:

Declare a constant called `maxValues` that is of type `Int` with the value 10.

You can change the value of an existing variable to another value of a compatible type. For example the currentValue can be incremented.
```swift
var currentValue: Int = 4
currentValue = 0
```
Unlike a variable, the value of a constant can't be changed after it's set.
```swift
let languageName: String = "Flint"
languageName = "f" // This a compile-time error
```
---

## Literals
_Literals_ represent fixed values in source code that can be assigned to constants and variables.
- Integer (`Int`) literals can be written as decimal numbers e.g. `42`.
- Address (`Address`) literals are written as 40 hexadecimal digits prefixed by a `0x`
- Boolean (`Bool`) literals are simply `true` and `false`.
- List (`[T]` or `T[n]`) literals are of the form:
  - `[]` which defines a new empty List
  - In the future, we will have lists defined by `[x, y, z, ...]` where `x`, `y`, `z` etc. are literals of type `T`
- Dictionary (`[T: U]`) literals are of the form:
  - `[:]` which defines a new empty Dictionary
  -  In the future, we will have dictionary literals defined by `[x: a, y: b, z: c, ...]` where `x`, `y`, `z` are literals of type `T` and `a`, `b`, `c` are literals of type `U`

---

## Comments
Comments can be used to exclude text from your code. Comments are ignored by the compiler when compiled.

```swift
// This is a comment
```

---

## Operators
An operator is a special symbol used to check, change, or combine values. Flint supports most standard C operators and attempts to eliminate common coding errors.

### Arithmetic Operators
Flint supports the following _arithmetic operators_ for all number types:
- Addition (`+`)
- Subtraction (`-`)
- Multiplication (`*`)
- Division (`/`)
- Power (`**`)

```swift
1 + 2 // equals 3
5 - 3 // equals 2
2 * 3 // equals 6
10 / 2 // equals 5
```

Flint has unique [Safe Arithmetic](#safe-arithmetic)

### Assignment Operators
The _assignment_ operator (`a = b`) initializes or updates the value of a with the value of b:

```swift
let b: Int = 10
var a: Int = 5
a = b
// a is equal to 10
```
#### Compound Assignment Operators
Flint provides _compound assignment operators_ that combine assignment (`=`) with another operator. Namely:
  - Addition Compound (`+=`)
  - Subtraction Compound (`-=`)
  - Times Compound (`*=`)
  - Division Compound (`/=`)

### Boolean Operators
These operators all result in `Bool`
- Equal to (`==`)
- Not equal to (`!=`)
- OR (`||`)
- AND (`&&`)
- Less than (`<`)
- Less than or equal to (`<=`)
- Greater than (`>`)
- Greater than or equal to (`>=`)

```swift
1 == 1   // true because 1 is equal to 1
2 != 1   // true because 2 is not equal to 1
2 > 1    // true because 2 is greater than 1
1 < 2    // true because 1 is less than 2
1 >= 1   // true because 1 is greater than or equal to 1
2 <= 1   // false because 2 is not less than or equal to 1
```

true || false // true because one of true and false is true
true && false // false because one of true and false is false

---

## Contracts
Contracts lie at the heart of Flint. These are the core building blocks of your program's code. Inside of contracts you define constants and variables to be stored on the Chain.

Contracts are declared using the keyword `contract` followed by the contract name that will be used as the identifier.

```
contract Bank {
  // Variable Declarations
  var owner: Address
  let name: String = "Bank"
}
```
### Mutation
Smart contracts can remain in activity for a large number of years, during which a large number of state mutations can occur. To aid with reasoning, Flint functions cannot mutate smart contracts’ state by default. This helps avoid accidental state mutations when writing the code, and allows readers to easily draw their attention to the mutating functions of the smart contract.

### Visibility Modifiers
Variables declared in the contract can have modifiers in front of their declaration which control the automatic synthesis of variable accessors and mutators. By the nature of smart contracts all storage is visible already, but providing accessors makes that process easier.

```swift
public var value: Int
visible var name: String = Bank
visible var owner: Address
```

- `public` access synthesises an accessor and a mutator so that the storage variable can be viewed and changed by anyone.
- `visible` access synthesises an accessor to the storage variable which allows it to be viewed by anyone.
- private access means that nothing is synthesised _but_ both accessors and mutators can be manually specified.

---

## Control Flow

### For-In Loops
`for-in` loops can be used to iterate over a sequence (currently contract instance arrays and dictionary values, and [ranges](#ranges))
```
contract X {
  var names: [String]
  var fixedLen: Int[10]
  var dictionary: [Int: String]
}
```
For example, we can iterate over a variable length array `names` and bind the current iteration's value to the constant `name` of type: `String`.
```
for let name: String in names {}
```
We can also bind the iteration's value to a variable i.e. `i`. This will allow the modification of the variable `i` inside the body - which gets reset on each loop.
```
for var i: Int in fixedLen {}
```
```
for let value: String in dictionary {}
```
### If Statements
The `if` statement has a single condition. This should be either a Boolean expression (i.e. `x == 2`), or a valid let statement (i.e. of the form `let x: Int = call? alpha.f()`, where `call?` executes an external call). It executes a set of statements only if the condition evaluates to `true` (if it is a Boolean expression), or if the external call returns a value successfully (if it is a valid let statement).
```swift
if x == 2 {
  // ...
}

if let y: Int = call? alpha.f() {
  // function returned value, here available as `y`
}
```
#### Else Clauses
The `if` statement can also provide an alternative set of statements known as an `else` _clause_ which gets executed when the condition gets evaluated to `false`.
```swift
if x == 2 {
  // ...
} else {
  // ,,,
}

if let example: Bool = call(gas: 5000)? alpha.functionWithBoolReturn() {
  // function returned value, here available as `example`
} else {
  // no value returned, handle gracefully
}
```

When using `if let ...` statements, the `else` branch is used when an external call is not successful:

```swift
if let example: Bool = call(gas: 5000)? alpha.functionWithBoolReturn() {
  // function returned value, here available as `example`
} else {
  // no value returned (or external call failure), handle gracefully
}
```

---

## Functions
_Functions_ are self-contained blocks of code that perform a specific task, which is called using its identifier. In Flint functions are contained within [Protection Blocks](#protection-blocks).

They are defined with the keyword `func` followed by the identifier and the set of parameters and optional return type:
```swift
func identifier() {
  // ...
}
```

In Flint all functions are `private` by default and as such can only be accessed from within the contract body (see [access modifiers](#access-modifiers)).

### Function Parameters
Functions can also take parameters which can be used within the function. These must be declared in the function signature. Flint also supports parameters that take default values, but these must be declared at the end of the signature. Below is a function that [mutates](#mutating-modifier) the dictionary of peoples' names to add the Key, Value pair of caller's address and name. If the parameter `name` is not provided to the function call, then the default value of "John Doe" will be used. For more information about callers, see [Caller Bindings](#caller-bindings):
```swift
contract AddressBook {
  var people: [Address: String]
}

AddressBook :: caller <- (any) {
  mutating func remember(name: String = "John Doe") {
    people[caller] = name
  }
}
```

### Return Values
You can indicate the function's return type with the _return arrow_ `->`, which is followed by the return type.
```swift
AddressBook :: (any) {
  func name(address: Address) -> String {
    return people[address]
  }
}
```

### Calling Functions
Functions can then be called from within a contract behaviour block with the same identifier. The call arguments must be provided in the same order as the one they are declared in (in the function signature), and they must be labeled accordingly. If any of the optional parameters are not provided, then their default values are going to be used automatically.

For instance if we wanted to get the caller's name we can reuse the name function:
```swift
AddressBook :: caller <- (any) {
  func myName() -> String {
    return name(address: caller)
  }
}
```

### Function Attributes
Attributes annotate functions as having special properties, currently the only example of this is `@payable`. For more information, see [Payable](#payable).

### Function Modifiers
Functions can have any number of modifiers in front of their declaration - although conflicting modifiers will raise a compile-error and duplicated modifiers will be ignored.
#### Access Modifiers
- `public` access enables functions to be used within their contract and exposes the function to the interface of the contract as a whole when compiled.
- private access (default and not a keyword that is explicitly set) only enables functions to be used within their contract
#### Mutating Modifier
The `mutating` modifier specifies that the function mutates the contract storage. This means that the function changes the contract storage.

```swift
AddressBook :: caller <- (any) {
  func remember(name: String) { // compile-time error
    people[caller] = name // This statement is mutating
  }
}
```
```swift
AddressBook :: caller <- (any) {
  mutating func myName() -> String { // compile-time error as this function isn't mutating
    return name(caller)
  }
}
```


---

## Types

Flint is a _statically-typed_ language with a simple type system, with basic support for subtyping through [traits](#traits). Type inference is a planned feature.

Flint is a _type-safe_ language. A type safe language encourages clarity about the type of values your code can work with.

It performs _type checks_ when compiling code and flags any mismatched types as errors. This enables you to catch and fix errors as early as possible in the development process.


### Basic Types
|Type      | Description                              |
|----------|------------------------------------------|
|`Address` | 160-bit Ethereum Address                 |
|`Int`     | 256-bit integer                          |
|`Bool`    | Boolean value                            |
|`String`  | String value (currently max of 256 bits) |
|`Void`    | Void value                               |

### Dynamic Types
|Type      | Description             |
|----------|-------------------------|
| `Array` | Dynamic-size array. `[T]` is an array of element type T |
| `Fixed-size Array` | Fixed-size memory block containing elements of the same type. `T[n]` is an array of size `n`, of element type `T`.         |
| `Dictionary` | Dynamic-size mappings from one key type to a value type `[K: V]` is a a dictionary of key type `K` and value type `V`. |
| Structs | Struct values, including Wei, are considered to be of dynamic type. |
---

## Range
Flint includes two _range types_, which are shortcuts for expressing ranges of values. In particular it is designed to be used with `for-in` loops.

### Half-Open Range
The _half-open range operator_ (`a..<b`) defines a range that runs from a to b, but doesn't include b.
```swift
for let i: Int in (0..<count) {
  // ...
}
```

### Open Range
The _open range operator_ (`a...b`) defines a range that runs from a to b and does include b.
```swift
for let i: Int in (0...count) {
  // ...
}
```


---

## Structures
_Structures_ in Flint are general-purpose constructs that group state and functions that can be used as self-contained blocks. They use the same syntax as defining constants and variables for properties. Structure functions are not protected as they can only be called by (protected) contract functions, and are required to be annotated `mutating` if they mutate the struct's state.

### Definition
You introduce structures with the `struct` keyword and their definition is contained within a pair of braces:
```swift
struct SomeStructure {
  // Structure definition goes here
}
```

Here is an example of a structure definition:
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
The `Rectangle` structure definition describes only what a `Rectangle` would look like and what functionality they contain. They don't describe specific rectangles. To do that you create an instance of that structure.

```swift
let someRectangle: Rectangle = Rectangle()
```

When you create an instance, you initialize that structure with it's initial values - in this case a width and height of 0. This process can also be done manually using the `init` special declaration. You can access the properties of the current structure with the special keyword `self`

```swift
struct Rectangle {
  // Same definition as above with:
  public init(width: Int, height: Int){
    self.width = width
    self.height = height
  }
}
```

```swift
let bigRectangle = Rectangle(400, 10000)
```

### Accessing Properties/Functions
You can access properties/functions of an instance using _dot syntax_. In dot syntax, you write the property name immediately after the instance name, separated by a period (.), without any spaces.

```
someRectangle.width // evaluates to 0
someRectangle.area() // evaluates to 0 by calling the function area on the Rectangle instance someRectangle
```

In Flint, you can also access the functions of a struct using this syntax without creating an instance - as long as they don't contain instance properties. (In the future we will support the `static` keyword to do this)

```swift
struct Square {
  public shapeName() -> String {
    return "Square"
  }
}
```

```swift
Square.shapeName() // Evaluates to "Square"
```

### State Properties or Local Variables
Struct values can be declared as state properties or local variables/constants through their intialisers. When stored as a state property, the struct's data resides in EVM storage. When stored as a local variable, it resides in EVM memory, and a pointer is allocated on the EVM stack.


### Structs as function arguments
Structs can be passed _by reference_ using the *inout* keyword. The struct is then treated as an implicit reference to the value in the caller.

Passing structs by value (copying the struct into storage or memory) is a planned feature. (See https://github.com/flintlang/flint/issues/133)

```
func foo() {
  let s = S(8)
  byReference(s) // s.x == 10
  // byValue(s) // s.x == 10 (modification not persistent in this scope)
}

func byReference(s: inout S) {
  s.x = 10
}

// currently unsupported:
func byValue(s: S) {
  s.x = 12
}
```
---

## Enumerations
An _enumeration_ defines a common group of values with the same type and enables working with those values in a type-safe way within Flint code.

### Syntax
```swift
enum CompassPoint: Int {
  case north
  case south
  case east
  case west
}
```
The values defined in an enumeration (such as `north`, `south`, `east` and `west`) are its _enumeration cases_. They are declared using the `case` keyword.

Each enumeration defines a new type:
```swift
var direction: CompassPoint
direction = CompassPoint.north
```

### Associated Values
```swift
enum Numbers: Int {
  case one = 1
  case two = 2
  case three
  case four
}
```
You can assign so called _raw values_ to enumeration cases.

Flint will infer the raw value of cases by default based upon the last declared enumeration cases raw value. `Numbers.three` will equal 3 due to this.

---

# Flint Specific Features
---
## Safe Arithmetic
Safe arithmetic operators are also provided. The `+`, `-`, `*` and `**` operators throw an exception and abort execution of the smart contract when an overflow occurs. The `/` operator implements integer division. No underflows can occur as we do not support floating point types yet. The performance overhead of our safe operators are low.

In rare cases, allowing overflows is the programmer’s intended behaviour. Flint also supports
overflowing operators, `&+`, `&-`, and `&*`, which will not crash on overflows.


## Assets
Numerous attacks targeting smart contracts, such as ones relating to reentrancy calls (see TheDAO), allow hackers to steal a contract’s Ether. These happen because smart contracts encode Ether values as integers, making it is easy to make mistakes when performing Ether transfers between variables, or to forget to record Ether arriving or leaving the smart contract.

Flint supports special safe operations when handling assets, such as Ether. They help ensure the contract's state consistently represents its Ether value, preventing attacks such as TheDAO.

A simple use of Assets:
```swift
contract Wallet {
  var owner: Address
  var contents: Wei = Wei(0)
}

Wallet :: caller <- (any) {
  public init() {
    owner = caller
  }

  @payable
  public mutating func deposit(implicit value: Wei) {
    // Record the Wei received into the contents state property.
    // Value is passed by reference.
    contents.transfer(&value)
  }
}

Wallet :: (owner) {
  public mutating func withdraw(value: Int) {
    // Transfer an amount of Wei into a local variable. This
    // removes Wei from the contents state property.
    var w: Wei = Wei(&contents, value)

    // Send Wei to the owner's Ethereum address.
    send(owner, &w)
  }

  public func getContents() -> Int {
    return contents.getRawValue()
  }
}
```
Another example which uses Assets is the Bank example.
```swift
contract Wallet {
  var beneficiaries: [Address: Wei]
  var weights: [Address: Int]
  var bonus: Wei

  var owner: Address
}


Wallet :: (any) {
  @payable
  mutating func receiveBonus(implicit newBonus: inout Wei) {
    bonus.transfer(&newBonus)
  }
}

Wallet :: (owner) {
  mutating func distribute(amount: Int) {
    let beneficiaryBonus = bonus.getRawValue() / beneficiaries.count
    for let person: Address in beneficiaries {
      var allocation = Wei(from: &balance, amount: amount * weights[person])
      allocation.transfer(from: &bonus, amount: beneficiaryBonus)

      send(beneficiaries[i], &allocation)
    }
  }
}
```

`Wei` is an example of an asset, and it is a `struct` conforming to the `struct trait Asset`, available in the standard library. It is possible to declare custom structs which will behave like assets:

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

  mutating func setRawValue(value: Int) -> Int {
    rawValue = value
    return rawValue
  }

  func getRawValue() -> Int {
    return rawValue
  }
}
```

The `transfer` functions are declared in the `Asset` trait and are inherited automatically. For the time being, traits do not support default implementations for initialisers or variables, so custom assets have to include the code above.

---

## Protection Blocks

Flint introduces the concept of **protection blocks**. While traditional computer programs have an entry point (the _main_ function), smart contracts do not. After a contract is deployed on the blockchain, its code does not run until an Ethereum transaction is received. Smart contracts are in fact more akin to RESTful web services presenting API endpoints. It is important to prevent unauthorized parties from calling sensitive functions.

In Flint, functions of a contract are declared within protection blocks, which restrict when the enclosed functions are allowed to be called.

There are two elements to protection blocks, the caller protection and the optional type state protection (see [Type States](#type-states) for more detail). A protection block is minimally declared as the contract name (`Bank`) followed by a `::` and a caller group (`(manager)`).

Solidity uses function modifiers to insert dynamic checks in functions, which can for instance abort unauthorised calls. However, it is easy to forget to specify these checks, as the language does not require programmers to write them.
Having a language construct which protects functions from invalid calls could require programmers to systematically think about which parties should be able to call the functions they are about to define.

In Flint, functions of a contract are declared within protection blocks, which protect the functions from invalid access.

### Caller Group
Caller Groups consist of a list of Caller Members enclosed in parentheses. These Caller Members can be a function of type `Address -> Bool` or `() -> Address`, a contract state property of the types `Address`, `[Address]`, `[T: Address]` or `Address[n]`, or the special `any` keyword that denotes all addresses. For example, `(any)`, `(admin)`, `(owners, manager)` are all valid Caller Groups where `admin` and `manager` refer to a state property of type `Address` and `owners` refers to a state property of type `[Address]`

Functions inside these caller groups can only be called by an Ethereum Address (aka the caller address) that satisfies at least one of these Caller Members. The satisfaction comes in different forms depending on the member.
| Type | Satisfaction |
| ---- | -------------|
| `Address -> Bool` | The function is called with the caller as input, satisfied if returns true |
| `() -> Address` | The returned address must match the caller address |
| `Address` | The address property must match the caller address |
| `[Address]` | The caller address must be contained within the list of addresses |
| `[T: Address]` | The caller address must be contained with in the values of the dictionary |
| `any` | Always satisfied |

The Ethereum address of the caller of a function is unforgeable. It is not possible to impersonate another user, as a consequence of Ethereum’s mechanism which generates public addresses from private keys. Transactions are signed using a private key, and determine the public key of the caller. Stealing a caller capability would hence require stealing a private key. The recommended way for Ethereum users to transfer their ability to call functions is to either change the backing address of the caller capability they have (the smart contract must have a function which allows this), or to securely send their private key to the new owner, outside of the Ethereum platform.

Calls to Flint functions are validated both at compile-time and runtime, with runtime checks only being added where necessary.

---

### Static checking
In a Flint function, if a function call to another Flint function is performed, the compiler checks that the caller meets the caller protection.

Consider the following example.

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
Within the context of `foo`, the caller is regarded as any. It is not certain that the caller also satisfies the `manager` protection, so the compiler rejects the call.

---
### Dynamic checking
#### Attempt function calls
It is still possible for `foo` to satisfy the protections of the function `bar`.

For these cases, two additional language constructs exist:

- `try? bar()`: The function `bar`'s body is executed if, at runtime, the protections are satisfied (i.e. the caller satisfies the caller protection and the state of the contract satisfies the type state protection). The expression `try? bar()` returns a boolean if successful.
- `try! bar()`: If at runtime `bar`'s protections are not satisfied an exception is thrown and the body doesn't get executed. Otherwise, it does.

#### Calls from Ethereum users or non-Flint smart contracts
Functions to contracts on the Blockchain can also be called by users directly, through an Ethereum client, or another non-Flint smart contract.

For those cases, Flint checks at runtime whether the caller has the appropriate protections to perform the call, and throws an exception if not.

#### Multiple protections
A contract behavior declaration can be restricted by multiple caller protections.

Consider the following contract behavior declaration:
```
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {}
}
```
The function `forManagerOrCustomers` can only be called by either the manager, or any of the accounts registered in the bank.

Calls to functions of multiple protections are accepted if **each** of the protections of the enclosing function are compatible with **any** of the target function's protections.

Consider the following examples:

#### Insufficient protections
```swift
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
#### Sufficient protections
```swift
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
#### `any` is compatible with any caller protection
```swift
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
#### Static and dynamic checking
Just like single-member protection definitions, multi-member protections are checked both at compile-time and runtime.

### Caller Binding
Callers can be bound to temporary variables.

Consider the following example.
```swift
Bank :: account <- (accounts) {
  // This function is non-mutating
  public func getBalance() -> Int {
    return balances[account]
  }

  public mutating func transfer(amount: Int, destination: Address) {
    balances[account] -= amount
    balances[destination] += amount
  }
}
```
`withdraw` can be called by any caller which has an account in the bank. The caller's address is bound to the variable `account`, which can then be used in the body of the functions.

### Extended Example

```swift
contract ChildCollegeFund {
  var parent: Address
  var child: Address
  var canWithdraw: Bool = false
  var target: Int
  var contents: Wei = Wei(0)
}
// Anyone can initialise the contract.
// The contract can be deployed by anyone,
// and is initialised during contract deployment.
// This initialisation allows you to set the contract address.
ChildCollegeFund :: (any) {
  public init(parent: Address, child: Address, target: Int) {
    self.parent = parent
    self.child = child
    self.target = target
  }
}
// Functions both the parent and child can call.
ChildCollegeFund :: (parent, child) {
  public func getTarget() -> Int {
    return target
  }

  // Trying to withdraw() here would fail as it
  // requires the caller to be 'child' statically.
  // At runtime we can only know the caller has one
  // of the capabilities.
}

// Functions only the parent can call.
ChildCollegeFund :: (parent) {

  // The parent can deposit money
  @payable
  public mutating func deposit(implicit value: Wei) {
    contents.transfer(&value)
  }

  public mutating func allowWithdrawaL() {
    self.canWithdraw = true
  }

  public func getContents() -> Int {
    return contents.getRawValue()
  }

  public func getDistanceFromGoal() -> Int {
    // The caller of this function is known to be 'parent'
    // Therefore, the calls to getTarget and getContents can be performed
    return getTarget() - getContents() // OK
  }
}

// Functions only the child can call
ChildCollegeFund :: (child) {
  public mutating func withdraw() {
    assert(canWithdraw == false)
    send(child, &contents)
  }
}
```
---

## Payable
When a user creates a transaction to call a function, they can attach Ether to send to the contract. Functions which expect Ether to be attached when called must be annotated with the `@payable` annotation otherwise the transaction will revert when Ether is attached.

When adding the annotation, a parameter marked implicit of type `Wei` must be declared. `implicit` parameters are a mechanism to expose information from the Ethereum transaction to the developer of the smart contract, without using globally accessible variables defined by the language, such as `msg.value` in Solidity. This mechanism allows developers to name `implicit` variables themselves, and do not need to remember the name of a global variable.

Functions in Flint can be marked as payable using the `@payable` attribute. The amount of Wei sent is bound to an implicit variable:
```swift
@payable
public func receiveMoney(implicit value: Wei) {
  doSomething(value)
}
```
Payable functions may have an arbitrary amount of parameters, but exactly one needs to be implicit and of a currency type.

---

## Events
JavaScript applications can listen to events emitted by an Ethereum smart contract.

In Flint, events are declared in contract declarations. They use a similar syntax to functions, except using the keyword `event`. Like functions, some of the parameters can have default values, but these must be declared at the end of the signature.

Events can then be emitted using the keyword `emit` followed by an event call. An event call is similar to a function call (parameters must be provided in order, and they must have the correct label and type; if any optional parameters are omitted, their default value will be used automatically).

```swift
contract Bank {
  var balances: [Address: Int]

  event didCompleteTransfer(origin: Address, destination: Address, amount: Int)
}

Bank :: caller <- (any) {
  mutating func transfer(to: Address, value: Int) {
    balances[caller] -= value
    balances[to] += value

    // A JavaScript client could listen for this event
    emit didCompleteTransfer(origin: caller, destination: to, amount: value)
  }
}
```


---

## Type States
Flint introduces the concept of **type states**. Insufficient and incorrect state management in Solidity code have led to security vulnerabilities and unexpected behaviour in widely deployed smart contracts. Avoiding these vulnerabilities by the design of the language is a strong advantage.

In Flint, states of a contract are declared within protection blocks, which protect the enclosed function from invalid calls.
```swift
// Anyone can deposit into the Bank iff the state is Deposit
Bank @(Deposit) :: (any) { // Deposit is a state identifier.
  func deposit(address: Address) {
    // body
  }
}
```
States are identifiers declared in the contract's declaration.
```swift
contract Auction (Preparing, InProgress, Terminated) {}
// Preparing, InProgress, Terminated are State Identifiers
```

Note: The special state identifier `any` allows execution of the function in the group in any state.

Calls to Flint functions are validated both at compile-time and runtime.

```swift
contract Auction (Preparing, InProgress, Terminated) { // Enumeration of states.
  var beneficiary: Address
  var highestBidder: Address
  var highestBid: Wei
}

Auction @(any) :: caller <- (any) {
  public init() {
    self.beneficiary = caller
    self.highestBidder = caller
    self.highestBid = Wei(0)
    become Preparing
  }
}

Auction @(Preparing) :: (beneficiary) {
  public mutating func setBeneficiary(beneficiary: Address) {
    self.beneficiary = beneficiary
  }

  mutating func openAuction() -> Bool {
    // ...
    return true
    become InProgress
  }
}
Auction @(InProgress) :: (beneficiary) {

  mutating func endAuction() {
    // ...
    become Terminated
  }
}

Auction @(InProgress) :: (any) {
  @payable
  func bid(implicit value: Wei) -> Bool{
    // ...
    // State is not explicitly changed.
    return Bool
  }
}
```


---

## Traits
We introduce the concept of ‘traits’ to Flint based in part on [Rust Traits](https://doc.rust-lang.org/rust-by-example/trait.html). Traits describe the partial behaviour of Contract or Structures which conform to them. For Contracts, traits constitute a collection of functions and function stubs in restriction blocks, and events. For Structures, traits only constitute a collection of functions and function stubs.

Contracts or Structures can conform to multiple traits. The Flint compiler enforces the implementation of function stubs in the trait and allows usage of the functions declared in them. Traits allow a level of abstraction and code reuse for Contracts and Structures. We also plan to have Standard Library Traits that can be inherited which provide common functionality to Contracts (Ownable, Burnable, MultiSig, Pausable, ERC20, ERC721, etc.) and Structures (Transferable, RawValued, Describable etc.).
It will also form the basis for allowing end users to access compiler level guarantees and restrictions as in [Assets](/proposals/0001-asset-trait.md) and Numerics.


### Structure Traits
Traits can be implemented for structures using the keyword combination of `struct trait` followed by a unique identifier before the block of trait members.

Structure traits can contain functions, function signatures, initialisers, or initialiser signatures.
A signature is simply missing a code block following it.

In the example below we define an `Animal` structure trait. The `Person` structure then conforms to the `Animal` `trait` allowing the use of functions within that.
```swift
struct trait Animal {
  // Must have an empty and named initialiser
  public init()
  public init(name: String)

  // These are signatures that conforming structures must implement
  // access properties of the structure
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

  // People always have a name, it's just not always known
  func isNamed() -> Bool {
    return true
  }
  // These access the properties of the struct
  public func name() -> String {
    return self.name
  }

  public func noise() -> String {
    return "Huh?"
  }

  // Person can also have functions in addition to Animal
  public func greet() -> String {
    return "Hi"
  }
}

```
### Contract Traits
Traits can be implemented for structures using the keyword combination of `contract trait` followed by a unique identifier before the block of trait members.

Contract traits can contain anonymous contract behaviour declarations containing methods or method signatures, or events.

In the example below, we define `Ownable`, which declares a contract as something that can be owned and transferred. The `Ownable` `trait` is then specified by the `ToyWallet` `contract` allowing the use of methods in `Ownable`. This demonstrates how we can expose contract properties:

```swift
contract trait Ownable {
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


---
# Standard Library
---
## Wei
The standard library defines the `Wei` type. For full details see [Assets](#assets)

## Global Functions
### Assertion
Assertions are checks that happen at runtime. They are used to ensure an essential condition is satisfied before executing any further code. If the Boolean condition evaluates to true then the execution continues as usual. Otherwise the transaction is reverted.
It is a global function accessible from any contract or contract group:
```
assert(x == 2)
```

In essence an assertion is a shorthand for the longer:
```
if x == 2 {
  fatalError()
}
```

### Fatal Error
`fatalError()` is a function exposed that reverts a transaction when called. This means that any contract storage changes are rolledback and no values are returned.

### Send
`send(address: Address, value: inout Wei)` sends the `value` Wei to the Ethereum address `address`, and clears the contents of `value`.

---
# Examples
---

## Bank Smart Contract
The following code declares the Bank contract and its functions. More examples are available on GitHub.

```swift
// Contract declarations contain only their state properties.
contract Bank {
  var manager: Address
  var balances: [Address: Wei] = [:]
  var accounts: [Address] = []
  var lastIndex: Int = 0

  var totalDonations: Wei = Wei(0)
  var didCompleteTransfer: Event<Address, Address, Int>
}

// The functions in this block can be called by any user.
Bank :: account <- (any) {
  public init(manager: Address) {
    self.manager = manager
  }

  // Returns the manager's address.
  public mutating func register() {
    accounts[lastIndex] = account
    lastIndex += 1
  }

  public func getManager() -> Address {
    return manager
  }

  @payable
  public mutating func donate(implicit value: Wei) {
    // This will transfer the funds into totalDonations.
    totalDonations.transfer(&value)
  }
}

// Only the manager can call these functions.
Bank :: (manager) {

  // This function needs to be declared "mutating" as its body mutates
  // the contract's state.
  public mutating func freeDeposit(account: Address, amount: Int) {
    var w: Wei = Wei(amount)
    balances[account].transfer(&w)
  }

  public mutating func clear(account: Int) {
    balances[account] = Wei(0)
  }

  // This function is non-mutating.
  public func getDonations() -> Int {
    return totalDonations.getRawValue()
  }
}

// Any user in accounts can call these functions.
// The matching user's address is bound to the variable account.
Bank :: account <- (accounts) {
  public func getBalance() -> Int {
    return balances[account].getRawValue()
  }

  public mutating func transfer(amount: Int, destination: Address) {
    // Transfer Wei from one account to another. The balances of the
    // originator and the destination are updated atomically.
    // Crashes if balances[account] doesn't have enough Wei.
    balances[destination].transfer(&balances[account], amount)

    // Emit the Ethereum event.
    didCompleteTransfer(account, destination, amount)
  }

  public mutating func withdraw(amount: Int) {
    // Transfer some Wei from balances[account] into a local variable.
    let w: Wei = Wei(&balances[account], amount)

    // Send the amount back to the Ethereum user.
    send(account, &w)
  }
}
```
