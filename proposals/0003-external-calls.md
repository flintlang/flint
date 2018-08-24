# Introduce External Calls

* Proposal: [FIP-0003](0003-external-calls.md)
* Author: [Daniel Hails](https://github.com/djrhails) & [Alexander Harkness](https://github.com/bearbin)
* Review Manager: TBD
* Status: **Awaiting review**
* Issue label: [0003-external-calls](https://github.com/franklinsch/flint/issues?q=is%3Aopen+is%3Aissue+label%3A0003-external-calls)

## Introduction

Contracts can be created "from outside" via Ethereum transactions or from within Flint Contracts. They contain persistent data in state variables and functions that can modify these variables. Calling a function on a different contract (instance) will perform an EVM Function call and thus switch the context such that state variables are inaccessible.

## Motivation
Calls to untrusted contracts can introduce several unexpected risks or errors. External call may execute malicious code in that contract _or any other contract_ that it depends upon. As such, **every** external call should be treated as a security risk.

However external calls are necessary to accomplish key features of smart contracts, including:
- Paying other users
- Interacting with other Contracts e.g. Tokens or Wallets

There have been pre-existing attempts to defined best practices for programming with respect for external calls ([Consensys Recommendations](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls), [OpenZeppelin](http://openzeppelin.org/), [Solium Security](https://github.com/duaraghav8/solium-plugin-security), [Mythril](https://github.com/ConsenSys/mythril), [Solcheck](https://github.com/federicobond/solcheck)). This proposal will try and integrate these best practices into the language design itself. Below are the following causes for concern with regard to external calls.

#### 1. Contracts are untrustworthy by default
```javascript
// bad
Bank.withdraw(100); // Unclear whether trusted or untrusted

function makeWithdrawal(uint amount) { // Isn't clear that this function is potentially unsafe
    Bank.withdraw(amount);
}

// good
UntrustedBank.withdraw(100); // untrusted external call
TrustedBank.withdraw(100); // external but trusted bank contract maintained by XYZ Corp

function makeUntrustedWithdrawal(uint amount) {
    UntrustedBank.withdraw(amount);
}
```

#### 2. External calls have arbitrary code execution
##### Race Conditions
Whether using raw calls (of the form `someAddress.call()`) or contract calls (of the form `ExternalContract.someMethod()`), assume that malicious code might execute. Even if ExternalContract is not malicious, malicious code can be executed by any contracts it calls.
One particular danger is malicious code may hijack the control flow, leading to race conditions.

##### Re-entrancy
- `someAddress.send()` and `someAddress.transfer()` are considered safe against reentrancy. While these methods still trigger code execution, the called contract is only given a stipend of 2,300 gas which is currently only enough to log an event.
  - Prevents reentrancy but is incompatible with any contract whose fallback function requires 2 300 gas or more

#### 3. External calls can silently fail
Solidity offers low-level call methods that work on rawAddress: `address.call()`, `address.callcode()`, `address.delegatecall()`, `address.send()`. These low-level methods never throw an exception.

```javascript
// bad
someAddress.send(55);
someAddress.call.value(55)(); // this is doubly dangerous, as it will forward all remaining gas and doesn't check for result
someAddress.call.value(100)(bytes4(sha3("deposit()"))); // if deposit throws an exception, the raw call() will only return false and transaction will NOT be reverted

// good
if(!someAddress.send(55)) {
    // Some failure code
}

ExternalContract(someAddress).deposit.value(100);
```

#### 4. Interfaces can easily be incorrectly specified
The interface is incorrectly defined. `Alice.set(uint)` takes an `uint` in `Bob.sol` but `Alice.set(int)` a `int` in `Alice.sol`. The two interfaces will produce two differents method IDs. As a result, Bob will call the fallback function of Alice rather than of `set`.

- [King of the Ether](https://www.kingoftheether.com/postmortem.html) (line numbers:
	[100](KotET_source_code/KingOfTheEtherThrone.sol#L100),
	[107](KotET_source_code/KingOfTheEtherThrone.sol#L107),
	[120](KotET_source_code/KingOfTheEtherThrone.sol#L120),
	[161](KotET_source_code/KingOfTheEtherThrone.sol#L161))

## Proposed solution
The following solution is partially based upon the [Command Design Pattern]() and the [Oraclize Engine](https://docs.oraclize.it/). They allow for execution of the argument if other given conditions are met (as specified by the compiler). A valid external call should specify the following, some of these can be auto-filled by the compiler:
- The contract address
- The function name
- The parameters
- The gas allocation
- The ether allocation

Considering our motivations below:
1. Contracts are untrustworthy by default
1. Arbitrary code execution
1. Silent Failure
1. Interfaces incorrectly specified

We broadly separate external calls into two types: _Educated Calls_ and _Uneducated Calls_. Educated calls are those accessed through Nodule (The Flint Package Manager) (or those which Flint has the source files for and deploys internally to the contract i.e. Hub and Spoke Topology). Uneducated calls are those with an ABI interface or Trait interface.

Uneducated calls should be treated untrustworthy (1) and as such visually flagged in the source language as dangerous. Using a bang (!) would be consistent with the attempt call syntax for forcing a call without all information. In order to make a call we should specify the parameters for the call and to provide flexibility the default parameters should be at their minimum values. For instance the default gas provided should be 2300 (the amount given for just sending ether) with an option to send all gas.

Educated calls meanwhile are not guaranteed to not introduce errors, but they have certain guarantees attached. These means that it combats (1), (2), (4):
1. That there is a defined function at the end of the call
2. That function obeys the modifiers given
3. That function has the same return types and parameter types as defined
4. The contract you call matches the source code given
5. The gas provided should be inferred by gas estimation over flint

We propose a method to both declare this interface within Flint, use the Nodule (The Flint Package Manager) to extract an interface, or call contracts uneducated.

In _Uneducated Calls_, the contract (Client), sets the properties of the director which then sets up the command which is finally sent to the contract.
The aim is to encapsulate a request as an object, thereby letting Flint parametrize clients with different requests.

(3) is combated by having necessary catching of all external calls - or prefixing with `try!` and `try?` to revert and nullify respectively.

### Uneducated Calls
#### Interface specified
```swift
interface Alpha(State1, State2) {
  var owner: Address

  Alpha @(State1) :: (any) {
    func doesNothing()
  }
  Alpha @(any) :: (owner) {
    func doesNothingWithArgs(Int, Int, Int)
    func withdraw() -> Int
    func deposit(Int) -> Bool
  }
  @payable
  func expensiveFunction()
}

let alpha: Director<Alpha> = 0x000... with Alpha

try alpha!.doesNothing() {
  // Successful Call
}
catch {
  // If it fails
}
try! alpha!.doesNothingWithArgs(x, y, z)
// If catch can not be provided if try! is used and then the transaction reverts on failure

try! alpha!.withdraw() // This flags an error as the return value is not dealt with

try! boundReturn <- alpha!.getReturn() {
  // Optionally does something with boundReturn
}

// Setting contract instance properties
alpha!.value = Wei(200)
alpha!.gas = Gas(2000)
alpha.trust() // Removes the need for a bang
try! alpha.expensiveFunction()
```
#### Foreign Function Interface
Flint smart contract can call functions from Solidity smart contracts and vice-versa, thanks to the Flint Foreign Function Interface (FFI).

The Flint FFI allows smart contracts to import a Solidity contract, in order to statically check the validity of external function calls.

```swift
@foreign import ForeignContract // A Solidity contract

contract Foo {}

Foo :: (any) {
  func foo(address: Address) -> Int {
    return (address as ForeignContract)!.getValue()
  }
}
```


### Educated Calls

#### Nodule: Flint Package Manager
```swift
// Creates a contract from the data stored in Nodule
var tokenInstance: Contract<ERC.Token> = Nodule.knap(0x000...)
```
#### Source Code
A contract's source code can be imported by:
- Directly downloading its source files
- Providing a web URL
- Finding the Flint contract in the (future) Flint Package Manager

```swift
import http://dsadsadas.com/contract.flint as URLContract
import FileContract
import Directory.Contract

let contract: Contract<URLContract> = deploy(URLContract)
contract.argumentName() // Value and Gas are automatically set based upon properties
```

There are two types of external calls: Educated Calls and Uneducated calls. Educated calls are those that utilise an ABI interface (or those which Flint has the source files for i.e. other Flint contracts) while uneducated calls are those without this interface.

We propose a method to both declare this interface within Flint, use the Nodule (The Flint Package Manager) to extract an interface, or call contracts uneducated.


```swift
// Uneducated Call methods
0x863df6bfa4469f3ead0be8f9f2aae51c91a907b4.call()

var contractAddress: Address = 0x000...
contractAddress.call()
contractAddress.callWithArguments()
var boundReturn = contractAddress.call()

// Transaction Call
var transaction: Call = Call()
transaction.value = Wei(200000)

transaction.run(contractAddress)

// Educated Call methods
contract Alpha {
  func withdraw() -> Int
  func deposit() -> Bool
}

// <=>
contract Alpha = "0xab55044d00000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000880000000000000000000000000000000"

import ERC.Token

var alphaInstance: Contract<Alpha> = Alpha(0x000...)
var tokenInstance: Contract<ERC.Token> = ERC.Token(0x000...)


```swift
var tokenInstance: Contract<ERC.Token> = Nodule.knap(0x000...) // Creates a contract from the data stored in Nodule
```

### ABI
Behind the scenes all of these interfaces are decoded into ABI function calls. [ABI Specification](https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html)
```
"dave", true and [1,2,3]

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

## Semantics
- Calls with value have payable modifier
- Return values must be checked
- Avoid multiple external calls in single transaction. External calls can fail accidentally or deliberately
- Critical functions such as sends with non-zero values or suicide() are callable by anyone or sender is compared to address that can be writtent to by anyone
- Payable transaction doesn't revert in the case of failure

### Warnings
#### Warn on "effects" after "interactions"
If the contract storage is changed after an external call then a warning should be emitted. This should encourage two things:
1. `checks-effects-interactions` pattern
2. `Pull over push` for external calls. This is considered a [best practice](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls) as it helps isolate each external call into its own transaction that can be initiated by the recipient of the call.


```javascript
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

### Unsafe operations


### Unsupported operations



## Possible future extensions



## Alternatives considered
