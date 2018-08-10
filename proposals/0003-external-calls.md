# Introduce External Calls

* Proposal: [FIP-0003](0003-external-calls.md)
* Author: [Alexander Harkness](https://github.com/bearbin) & [Daniel Hails](https://github.com/djrhails)
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

There have been pre-existing attempts to defined best practices for programming with respect for external calls ([Consensys Recommendations](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls), [OpenZeppelin](http://openzeppelin.org/), [Solium Security](https://github.com/duaraghav8/solium-plugin-security), [Mythril](https://github.com/ConsenSys/mythril), [Solcheck](https://github.com/federicobond/solcheck)). This proposal will try and integrate these best practices into the language design itself.

#### 1. Contracts should be labelled as untrustworthy
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

#### 2. Arbitrary code execution can lead to race conditions
Whether using raw calls (of the form `someAddress.call()`) or contract calls (of the form `ExternalContract.someMethod()`), assume that malicious code might execute. Even if ExternalContract is not malicious, malicious code can be executed by any contracts it calls.
One particular danger is malicious code may hijack the control flow, leading to race conditions.

If you are making a call to an untrusted external contract, avoid state changes after the call. This pattern is also sometimes known as the `checks-effects-interactions` pattern.

#### 3. External calls can re-enter contracts
- `someAddress.send()` and `someAddress.transfer()` are considered safe against reentrancy. While these methods still trigger code execution, the called contract is only given a stipend of 2,300 gas which is currently only enough to log an event.
  - Prevents reentrancy but is incompatible with any contract whose fallback function requires 2 300 gas or more

#### 4. External calls can silently fail
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

#### 6. Money can be left unextractable due to external calls
Should also _always_ able to clear or extract funds from contract. Many bugs have lost significant sums due to this ability e.g. with the above:

```
function clear() public onlyOwner onlyEnded {
  require(now > endedAt + coolingPeriod)
  require(ended)
  var leftOver = totalBalance()
  owner.transfer(leftOver)
  ClearEvent(owner, leftOver)
}
```

#### 7. Interfaces can easily be incorrectly specified
The interface is incorrectly defined. `Alice.set(uint)` takes an `uint` in `Bob.sol` but `Alice.set(int)` a `int` in `Alice.sol`. The two interfaces will produce two differents method IDs. As a result, Bob will call the fallback function of Alice rather than of `set`.

- [King of the Ether](https://www.kingoftheether.com/postmortem.html) (line numbers:
	[100](KotET_source_code/KingOfTheEtherThrone.sol#L100),
	[107](KotET_source_code/KingOfTheEtherThrone.sol#L107),
	[120](KotET_source_code/KingOfTheEtherThrone.sol#L120),
	[161](KotET_source_code/KingOfTheEtherThrone.sol#L161))

#### Favor pull over push for external calls
To minimize the damage caused by such failures, it is often better to isolate each external call into its own transaction that can be initiated by the recipient of the call. This is especially relevant for payments, where it is better to let users withdraw funds rather than push funds to them automatically. Avoid combining multiple send() calls in a single transaction. [push-pull mechainism](https://consensys.github.io/smart-contract-best-practices/recommendations/#favor-pull-over-push-for-external-calls) using the send()/transfer() for push component and call.value()() for the pull component.


```
// bad
contract auction {
    address highestBidder;
    uint highestBid;

    function bid() payable {
        require(msg.value >= highestBid);

        if (highestBidder != 0) {
            highestBidder.transfer(highestBid); // if this call consistently fails, no one else can bid
        }

       highestBidder = msg.sender;
       highestBid = msg.value;
    }
}

// good
contract auction {
    address highestBidder;
    uint highestBid;
    mapping(address => uint) refunds;

    function bid() payable external {
        require(msg.value >= highestBid);

        if (highestBidder != 0) {
            refunds[highestBidder] += highestBid; // record the refund that this user can claim
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdrawRefund() external {
        uint refund = refunds[msg.sender];
        refunds[msg.sender] = 0;
        msg.sender.transfer(refund);
    }
}
```

## Proposed solution
- We shouldn't support call.value() directly only send
- Any call which has a value has payable modifier
- Return value from an external call *must* be checked [Unchecked Return Value](https://consensys.github.io/smart-contract-best-practices/recommendations/#handle-errors-in-external-calls)
- Explicitly mark all external contracts as trusted or untrusted
- Avoid multiple external calls in single transaction. External calls can fail accidentally or deliberately.
- Critical functions such as sends with non-zero values or suicide() are callable by anyone or sender is compared to address that can be written to by anyone
- Contract state shouldn't be relied on if untrusted contracts are called. State changes after external calls should be avoided
- Payable transaction does not revert in case of failure

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


```

```

## Semantics


### Warnings


### Unsafe operations


### Unsupported operations



## Possible future extensions



## Alternatives considered
