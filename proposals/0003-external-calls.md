# Introduce External Calls

* Proposal: [FIP-0003](0003-external-calls.md)
* Authors: [Daniel Hails](https://github.com/djrhails), [Alexander Harkness](https://github.com/bearbin), [Aurel Bílý](https://github.com/Aurel300)
* Review Manager: [Susan Eisenbach](https://github.com/SusanEisenbach)
* Status: **Awaiting review**

## Introduction

Contracts can be created "from outside" via Ethereum transactions or from within Flint Contracts. They contain persistent data in state variables and functions that can modify these variables. Calling a function on a different contract (instance) will perform an EVM Function call and thus switch the context such that state variables in the old context are inaccessible.

## Motivations

Calls to untrusted contracts can introduce several unexpected risks and errors.

When the internal contract calls to an external contract (i.e. the callee contract) the callee may execute, potentially malicious, but always arbitrary code. This code can itself include external calls to any other contract, which themselves allow arbitrary code execution and so on.

As such, **every** external call should be treated as a security risk because it requires the integrity of every contract in this chain.

However external calls are necessary to accomplish key features of smart contracts, including:

 - Paying other users
 - Interacting with other Contracts e.g. Tokens or Wallets

There have been several published best practice guidelines for programming with external calls ([Consensys Recommendations](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls), [OpenZeppelin](http://openzeppelin.org/), [Solium Security](https://github.com/duaraghav8/solium-plugin-security), [Mythril](https://github.com/ConsenSys/mythril), [Solcheck](https://github.com/federicobond/solcheck)). This proposal will attempt to integrate best practices into the language design. Below are causes for concern with external calls:

 1. Contracts are untrustworthy by default;
 2. External calls may execute arbitrary code;
 3. External calls may fail silently;
 4. Interfaces may be incorrectly specified.

### 1. Contracts are untrustworthy by default

```javascript
// Bad style:
Bank.withdraw(100); // Unclear whether trusted or untrusted

function makeWithdrawal(uint amount) { // It isn't clear that this function is potentially unsafe
  Bank.withdraw(amount);
}

// Better style:
UntrustedBank.withdraw(100); // Untrusted external call
TrustedBank.withdraw(100); // External but trusted bank contract maintained by XYZ Corp

function makeUntrustedWithdrawal(uint amount) { // Name is explicit
  UntrustedBank.withdraw(amount);
}
```

It is possible to indicate trustworthiness of contracts using proper naming of functions and variables. However, this is at the discretion of the programmer and can be easily overlooked when dealing with a more complex codebase.

Instead, the language syntax itself (or the compiler) should make it plain that external calls are potentially dangerous.

### 2. External calls may execute arbitrary code

Calling functions of an external contract is also problematic since the control flow is completely taken over by the called contract and there is no way to limit exactly what the external contract will do. Consider a simple bank-like contract which stores the balances of clients (in the `put` function) and then allows clients to take out their balance (in the `get` function):

```swift
contract HoneyPot {
  var balances: [Address: Int] = [:]
}

HoneyPot :: caller <- (any) {
  @payable
  public init() {
    put()
  }

  @payable
  public mutating func put(implicit value: Wei) {
    balances[caller] = value.getRawValue()
  }

  public mutating func get() {
    // START OF SOLIDITY SYNTAX
    if (!caller.collectMoney.value(balances[caller])()) {
      throw;
    }
    // END OF SOLIDITY SYNTAX
    balances[caller] = 0
  }
}
```

In `put`, the contract sets the value of the `caller` address balance to zero only after checking if sending Ether to `caller` goes through.

But consider a malicious `AttackContract` designed to take advantage of the badly-written `get` function:

```swift
contract AttackContract {
  public init() {
    let honeyPot: Address = 0x.... // address of the deployed HoneyPot
    // START OF SOLIDITY SYNTAX
    honeyPot.put.call.value(1000)(); // so balances[caller] is 1000
    honeyPot.get.call(); // start the attack
    // END OF SOLIDITY SYNTAX
  }

  @payable
  public mutating func collectMoney(implicit value: Wei) {
    // START OF SOLIDITY SYNTAX
    honeyPot.get.call(); // collect more money!
    // END OF SOLIDITY SYNTAX
  }
}
```

The call chain might look something like:

 - `AttackContract.init()`
   - `HoneyPot.put()`
   - `HoneyPot.get()`
     - `AttackContract.collectMoney()`
       - `HoneyPot.get()`
         - `AttackContract.collectMoney()`
           - ...

That is, the `collectMoney` function calls `HoneyPot.get()` _before_ the call to `collectMoney` is finished. This means that `balance[caller]` is never set to zero and more and more money (in multiples of the original `balance[caller]`) is transferred from `HoneyPot` to `AttackContract`.

This illustrates how easily control flow can be hijacked due to external calls.

In Solidity, `someAddress.send()` and `someAddress.transfer()` are considered safe against re-entrancy due to a workaround: while these methods still trigger code execution, the called contract is only given a stipend of `2300 gas` which is currently only enough to log an event. This:

 - Prevents re-entrancy attacks but is incompatible with any contract whose `fallback` function requires 2300 gas or more.
 - Sometimes the programmer won't want this, but then has to fall back onto the dangerous raw calls.

In most cases, re-entrancy is not desirable, so Flint should prevent external calls to call functions of the caller (Flint) contract.

### 3. External calls may fail silently

Solidity offers low-level call methods that work on `rawAddress`: `address.call()`, `address.callcode()`, `address.delegatecall()`, `address.send()`. These low-level methods never throw an exception so they fail silently.

The following are examples of pre-exisiting solutions for external calls in solidity.

```javascript
// Fails silently:
someAddress.send(55);

// This is doubly dangerous, as it will forward all remaining gas and doesn't check for result:
someAddress.call.value(55)();

// If deposit throws an exception, the raw call() will only return false and transaction will NOT be reverted:
someAddress.call.value(100)(bytes4(sha3("deposit()")));

// Better:
if (!someAddress.send(55)) {
  // Some code to handle the failure
}

ExternalContract(someAddress).deposit.value(100);
```

Flint should force the programmer to deal with potential failures of _any_ external calls, by enforcing that any external call should be wrapped in a `do-try-catch` block.

### 4. Interfaces may be incorrectly specified

Minor errors in interfaces may lead to wrong code being executed. For instance, consider the following deployed contract:

```swift
contract Bob {
  public func set(value: Bool) {
    // ...
  }
}
```

To call `Bob.set()`, the contract `Alice` has to specify the interface (trait) for `Bob`, but it may easily be specified incorrectly:

```
contract trait Bob {
  public func set(value: Int) // note Int instead of Bool
}

contract Alice {
  func callBob() {
    let bob: Bob = 0x...
    bob.set(1)
  }
}
```

The two will produce different method IDs. As a result, `Alice` will call the fallback function of `Bob` rather than `set`, most likely with unwanted results.

This type of error is responsible for the bug in [King of the Ether](https://www.kingoftheether.com/postmortem.html) (line numbers:
	[100](https://github.com/kieranelby/KingOfTheEtherThrone/blob/master/contracts/KingOfTheEtherThrone.sol#L100),
	[107](https://github.com/kieranelby/KingOfTheEtherThrone/blob/master/contracts/KingOfTheEtherThrone.sol#L107),
	[120](https://github.com/kieranelby/KingOfTheEtherThrone/blob/master/contracts/KingOfTheEtherThrone.sol#L120),
	[161](https://github.com/kieranelby/KingOfTheEtherThrone/blob/master/contracts/KingOfTheEtherThrone.sol#L161))

## Proposed solution

The following solution was reworked following the discussion on October 25th, with the following goals in mind, roughly in order of decreasing importance:

 1. External contracts should be considered untrustworthy, and there will not (yet) be a way to change this.
 2. External calls should always be surrounded with `do-catch` blocks, where any call implies a `try`.
 3. Any data related to an external call should be specified at the call site.
 4. External calls should have a syntax distinct from regular function calls.
 5. The supporting syntax should feel similar to Swift (wherever possible).

A valid external call should specify the following data:

 - Contract (`callee`) address
 - Function name
 - Function arguments
 - Gas allocation
 - Ether (Wei) allocation

Gas allocation and Ether allocation are special values that the external function uses / consumes, but they do not form a part of its signature; they are implicit in EVM. In the remainder of the text they will be referred to as "hyper-parameters".

### Code example

The function interface of the external contract has to be specified using an "external" trait. External traits are similar to contract traits, but have a number of limitations, due to the nature of the low-level ABI of Solidity and the fact that Flint-specific features cannot be supported on Solidity contracts:

 - Type states cannot be specified
 - Caller protection blocks cannot be specified
 - `mutating` or `public` keywords cannot be specified on functions
 - Default implementations cannot be specified
 - `Self` cannot be used

Some additional caveats:

 - Function arguments can be given labels, but these are for internal use only (since they do not affect the ABI signature)
 - Functions can be given return types, but there is no trivial way to check if a returned value is of the required type (e.g. a `Bool` `true` value has the same representation as a `Int` `1` in the Solidity ABI)
 - External traits have an implicit constructor, so that an address can be "cast" into the trait, allowing function calls
 - Functions of external trait instances cannot be called using the regular function call syntax, but must use the `call` keyword, which also allows hyper-parameters to be specified

```swift
external trait Alpha {
  func simpleFunction()
  func functionWithArguments(value: Int, tax: Int)
  func functionWithReturn() -> Int
  func functionWithBoolReturn() -> Bool
  
  @payable
  func expensiveFunction()
}
```

The trait can then be used in Flint code. First, to initialise it from an `Address`, we use the implicit constructor of external contracts:

```swift
let someAddress: Address = 0x... // deployed Alpha contract
let alpha: Alpha = Alpha(adress: someAddress)
```

Then we can call functions on `alpha` using the `call` keyword, which is modeled to resemble the semantics of `try` in Swift. It has the following grammar:

```
externalCall =
  "call" WSP
  [ "(" [expression] *( "," WSP expression ) ")" ] WSP
  [ "!" / "?" ] SP
  functionCall
```

In other words, following the `call` keyword, hyper-parameters may optionally be specified, then `!` (exit on error) or `?` (return an `Optional`) may optionally change the `call` mode, then the actual external call is specificed.

Examples of (syntactically) valid uses of the `!` mode, which will cause a transaction rollback on any error:

```swift
call! alpha.simpleFunction()
call! alpha.functionWithArguments(value: 1, tax: 2)
call(value: Wei(100))! alpha.expensiveFunction()
call(gas: 5000)! alpha.simpleFunction()
```

Examples of (syntactically) valid uses of the default mode, which must be used in a `do-catch` block:

```swift
do {
  call alpha.simpleFunction()
} catch ExternalCallError {
  // recover gracefully
}

do {
  call(value: Wei(100)) alpha.expensiveFunction()
  call(gas: 5000) alpha.simpleFunction()
} catch ExternalCallError {
  // recover gracefully from either (!) failure
}
```

Examples of (syntactically) valid uses of the `?` mode, which returns an optional, and is therefore best used in a `if let ...` condition:

```swift
if let returnedValue: Int = call? alpha.functionWithReturn() {
  // function returned value, here available as `returnedValue`
} else {
  // no value returned, handle gracefully
}

if let example: Bool = call(gas: 5000)? alpha.functionWithBoolReturn() {
  // function returned value, here available as `example`
} else {
  // no value returned, handle gracefully
}
```

Examples of invalid uses:

```swift
// error: user must specify an amount of Wei to pay (@payable)
call! alpha.expensiveFunction()

// error: must be used in `if let`
call? alpha.functionWithReturn()

// error: function doesn't have a return type
if let example: Int = call? alpha.simpleFunction() {
  // ...
}

// error: return type doesn't match expected type
if let example: Int = call? alpha.functionWithBoolReturn() {
  // ...
}

// error: must use `call` for external calls
alpha.simpleFunction()
```

### Hyper parameters

The `call` keyword accepts the following parameters:

 - `gas` - an `Int` value, specifying the computational time allowed for the external call; default: `2300`
 - `value` - a `Wei` value that is paid into the external contract; must be specified for functions marked `@payable`, otherwise invalid
 - `reentrant` - a `Bool` value that specifies if it should be possible to call functions of the current (Flint) contract from the external contract _during_ an external call (see re-entrancy problem discussed in motivation and re-entrancy discussion below); default: `false`

### `reentrant`

Just before an external call, the Flint contract is moved into a special type state. This type state is generated automatically by the compiler, and it disallows any function to be called, preventing re-entrancy issues. After the external call is finished (no matter what the result was) the contract is placed back into the previous type state.

This behaviour may be overridden if the user chooses to do so by specifying `reentrant: true` as a hyper-parameter to the `call` keyword.

### Implementation requirements

In the parser:

 - `call` keyword, grammar for `externalCall` expression (statement?)
 - `do-catch` blocks
 - `if let` blocks

In the semantic analyser:

 - check that `@payable` functions are given `wei`
 - check that non-`@payable` functions are not given `wei`
 - check that `if let ... = call? ...` calls a function with a return type
 - check that `if let ... = call? ...` calls a function with the correct return type
 - check that `call? ...` is used in `if let ...` (may be a parser check)
 - put bound return variable in scope of `if let ...` block

In the IR generator:

 - better exception handling (stack of exception handlers / addresses for each type of exception, for now only `ExternalCallError`)
 - rollback on unhandled exceptions / `!` mode
 - bind optional value to a variable in `if let ...`
 - add special external call type state, enter into it before a call, leave it after a call

Test suite:

 - add tests

### Solidity ABI
Behind the scenes all of these interfaces are decoded into ABI function calls. [ABI Specification](https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html)

```
function:    sam(bytes, bool, uint[])
called with: "dave", true, [1,2,3]

0:    a5643bf2                                                         <-- method ID
4:    0000000000000000000000000000000000000000000000000000000000000060 <-- arg1 offset
32:   0000000000000000000000000000000000000000000000000000000000000001 <-- true
64:   00000000000000000000000000000000000000000000000000000000000000a0 <-- offset 2
96:   0000000000000000000000000000000000000000000000000000000000000004 <-- length of arg1
128:  6461766500000000000000000000000000000000000000000000000000000000 <-- "dave"
160:  0000000000000000000000000000000000000000000000000000000000000003 <-- length of arg2
192:  0000000000000000000000000000000000000000000000000000000000000001 <-- arg2
224:  0000000000000000000000000000000000000000000000000000000000000002 <-- arg2
256:  0000000000000000000000000000000000000000000000000000000000000003 <-- arg2
```

### Warnings

If the contract storage is changed after an external call (i.e. the external call modified the state) then a warning should be emitted. This should encourage two things:

1. `checks-effects-interactions` pattern.
2. `Pull over push` for external calls. This is considered a [best practice](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls) as it helps isolate each external call into its own transaction that can be initiated by the recipient of the call.

```javascript
// SOLIDITY SYNTAX

// Without push-pull
function bid() payable {
  if (highestBidder != 0) {
    highestBidder.transfer(highestBid); // if this call consistently fails, no one else can bid
  }
  highestBidder = msg.sender;
  highestBid = msg.value;
}

// With push-pull
mapping(address => uint) refunds;

function bid() payable external {
  require(msg.value >= highestBid);
  if (highestBidder != 0) {
    // Push: record the refund that this user can claim
    refunds[highestBidder] += highestBid;
    // Could also emit an event as an Asynchronous trigger for the previous bidder to withdrawRefund
  }
  highestBidder = msg.sender;
  highestBid = msg.value;
}

function withdrawRefund() external {
  uint refund = refunds[msg.sender];
  refunds[msg.sender] = 0;
  msg.sender.transfer(refund);
}
```

## Alternatives considered

### Blind Calls

This acts as a direct translation to the ABI that gets called behind the scenes. This gives a low-level interface to the contract but is also highly prone to error.

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!
func callFoo(contractAddress: Address) {
  contractAddress.call(bytes4(sha3("foo(uint256)")), a)
}
```

### Variable binding

Results could also be bound to variables instead of an identifier:

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!
let boundReturn: Int = try! alpha!.withdraw()

try let boundReturn: Int = alpha!.withdraw then {
  // Use bound return
}
```

### Guard-like syntax

We could flip the catching of the call so you only specify the catch statement after it then continue code execution as normal. This would reduce the indentation of the language, but would then not match the if statement syntax.

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!
let alpha: Director<Alpha> = 0x000... with Alpha

try alpha!.doesNothing() else {
  // If it fails
}
// If it succeeds execution will continue

try! boundReturn <- alpha!.withdraw()
// Optionally does something with boundReturn
```

### Parameters of the call are appended

Calls need information such as the amount of gas to allocate or the Ether value to transfer. This contradicts the return type as: `address.foo` is of type `Void` and so must `address.foo.value(10)` be but `.value()` is not a property of the `Void` type. This means special cases would be needed for the type checker, and is just generally confusing.

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!
contract A {
  @payable
  public func foo(i: Int){
    // ...
  }
}

func callData(address: Address) {
  address.foo.value(10).gas(800)(5)
}
```

### Call Specification

This was rejected because it confuses both the function name, the arguments and the hyper parameters for the call. They are all assigned together.

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!
call Name {
  let name: String = "foo"
  let arg1: Int = 5
  let value: Wei = 10
  let gas: Gas = 800
}
```

### Previous version of this proposal

The following was the previous version of this proposal. Several issues have since been addressed, namely that contracts are always untrusted, that hyper-parameters were specified on a stateful `Director` (leading to potential problems when the state is specified far from an actual call), that the syntax seemed too different from Swift.

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!

// external contract Alpha
contract trait Alpha(State1, State2) {
  var owner: Address
}

Alpha @(State1) :: (any) {
  func doesNothing()
}

Alpha @(any) :: (owner) {
  func doesNothingWithArgs(a: Int, b: Int, c: Int)
  func withdraw() -> Int
  func deposit(value: Int) -> Bool
}

Alpha @(any) :: (any) {
  @payable
  func expensiveFunction()
}

contract AlphaUser {
  public init() {
    // Director allows external calls and setting of hyper-parameters
    let alpha: Director<Alpha> = 0x... // address of a deployed Alpha contract
    
    try alpha!.doesNothing() then {
      // Successful Call
    } catch {
      // If it fails
    }
    
    try! alpha!.doesNothingWithArgs(a: x, b: y, c: z)
    // Catch can not be provided by using try!, then if the call fails then transaction reverts.
    
    try! alpha!.withdraw() // This flags an error as the return value is not dealt with
    
    try! boundReturn <- alpha!.withdraw() then {
      // Optionally do something with boundReturn
    }
    
    // Setting hyper parameters
    // Asset types are atomically transferred to preserve special properties.
    alpha!.transfer(Wei(200))
    alpha!.allocate(Gas(2000))
    alpha.trust() // Removes the need for a bang
    try! alpha.expensiveFunction()
  }
}
```

The following features were completely removed from this proposal, since they have been deemed too ambitious / unnecessary for the time being:

 - Importing trusted contracts from the Flint Package Manager
 - Importing contracts from URLs
 - Deploying contracts

An example of the above features:

```swift
// THIS SYNTAX WILL NOT BE SUPPORTED!

// Creates a contract from the data stored in Flint Package Manager
import flint:0x... as ERCToken

// Then in a function:
ERCToken.transfer(...)

import https://flint.org/examples/contract.flint as URLContract
import FileContract
import Directory.Contract

// Then in a function:
let contract: Contract<URLContract> = deploy(URLContract)
contract.argumentName() // Value and Gas are automatically set based upon properties
```
