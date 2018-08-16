# Introduce Type States

* Proposal: [FIP-0002](0002-type-states.md)
* Author: [Alexander Harkness](https://github.com/bearbin), [Daniel Hails](https://github.com/djrhails)
* Review Manager: [Franklin Schrans](https://github.com/franklinsch)
* Status: Under Review
* Issue label: [0002-type-states](https://github.com/franklinsch/flint/issues?q=is%3Aopen+is%3Aissue+label%3A0002-type-states)

## Introduction

Smart contracts often have functions that are only usable at a certain phases in the life of a contract or transaction. Traditionally, at the start of every function there was a requirement on the programmer to check that the ‘state’ of the function matches up with what the function expected. This checking not only degrades performance but also opens the user to potential misbehaviour if it is incorrect or missing.

We introduce the concept of ‘Type States’, by which the matching of present and expected ‘states’ of the contract can be enforced automatically by the Flint language. Runtime checks could be removed for internal calls where the state would already be known. When the state is not known (during external calls, for example) calls would have a state check behind the scenes. Overall this would effectively result in the contract becoming a state machine, enforced by the compiler and type system.

By way of implementation, the contract is given a ‘state’ taking a predefined, enumerated, set of values, and function declarations give the acceptable states for calls to that function.
Functions are then able to set the state as they like, and calls to functions with incorrect state are rejected.

It would of course be up to the user to utilise the new concept, and if unsafe behaviour is desired then it would be allowed. The programmer could elect to ignore the concept of states entirely, or simply use ordinary contract properties and assertions at the start of function declarations to maintain their own state.

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
## Motivation

Insufficient and incorrect state management in Solidity code have led to security vulnerabilities and unexpected behaviour in widely deployed smart contracts. Avoiding these vulnerabilities by the design of the language is a strong advantage.

The first Parity Multi-Sig wallet hack was the result of a function being called when the contract was in the wrong state. Specifically the initWallet function was supposed to be called exclusively in the “initialization” phase of the smart contract. However, this function could actually be called at any stage in the lifetime of the contract, and allowed for an attacker to set themselves as the owner after the contract had already been initialised and Ether deposited, and therefore steal Ether from the wallet. The value of Ether lost at the time amounted to around $260 Million.
```javascript
function initWallet(address[] _owners, uint _required, uint _daylimit) {}

// Fix was the change below
modifier only_uninitialized { if (m_numOwners > 0) throw; _; }
function initWallet(address[] _owners, uint _required, uint _daylimit) only_uninitialized {}
```

Although this flaw was resolved in a later version of the contract, by the addition of a Solidity modifier `only_uninitialized` to the function in question, it did not address weaknesses in other areas of the contract, nor did it prevent similar issues happening in the future. Namely $300M was subsequently frozen because the modifier merely checked if the owner of the contract had been set, rather than explicitly encoding the current phase as in a state machine.

By explicitly encoding the current phase of contracts; forcing the programmer to consider the state properties of functions, and automatically enforcing these constraints, Flint would be able to avoid a major class of issues inherent to smart contracts today. The concept of Type States as proposed strikes a balance between ultimate safety and developer usability and flexibility. Although unsafe behaviour is possible, developers are forced to take into account safety as they write code and unsafe code is readily apparent to users.

## Proposed Solution

### State Definition
```swift
contract Auction (Preparing, InProgress, Terminated)
```
### State Restriction
```swift
Auction @(Preparing) :: (beneficiary)
Auction @(Preparing, InProgress) :: (beneficiary)
Auction @(Preparing) :: caller <- (beneficiary)
```
### State change
```swift
return variable
become InProgress
```
## Syntax Alternatives
Having state phases be capitalised e.g. `INITIALISATION`, this was rejected in favour of not having stylistic choices enforced in the language.

### State Definition
**Enum**
```swift
enum States {
  case Preparing
  case InProgress
  case Terminated
}

contract Auction (States)
```
### State Restriction
**Combined**
```swift
Auction :: (beneficiary, Preparing)
```
**Isolated**
```swift
Auction (Preparing) :: (beneficiary)
Auction (Preparing) :: caller <- (beneficiary)
```
**Separated**
```swift
Auction :: Preparing :: (beneficiary)
Auction :: (Preparing, InProgress) :: (beneficiary)
Auction :: (any) :: (any)
```
**Function Annotations**

In the following example all calls to `maybeTerminate` must take place with the state being `InProgress`, and the state after the function is called may be either `InProgress` or `Terminated`.

```swift
@mutating(InProgress -> (InProgress, Terminated))
func maybeTerminate() {}
```

### State Transition
**Stateful returns**
```swift
return (InProgress) var
```
**Assignment with custom operator to clearly assign state**
```swift
state <- InProgress
```
**Function Annotations**
```swift
@mutating(Preparing -> InProgress)
func openAuction() {}
```
**Reuse return type annotation with state**
```swift
func name() -> Int (InProgress) {
func maybeTerminate() -> Int (InProgress, Terminated)
func mtWithStateSpec() (InProgress -> (InProgress, Terminated)) -> Int
```
**Custom state annotation of functions with different bracket types**
```swift
@state<(InProgress, Started) -> (InProgress, Terminated)>
func mtWithAnnotatedSS() -> Int
func name() -[InProgress]-> Int {
```

### Dynamic checking for internal call in case of ambiguity:
```swift
func timeDependent() (InProgress -> (InProgress, Terminated)) -> Int {
  if (time > 5000) {
    state <- Terminated
  }
  return try! name() // State could be InProgress or Terminated, so try enables runtime checking. Otherwise would fail to compile. Same syntax as try?! for caller capabilities.
}
```

## Static Analysis
Requirements:
- All functions called must be called with correct state or dynamic checking enabled.
Optional Requirements:
- Check that all transitions are possible (not necessarily actually, but at least one layer down).
- Separate state transition function calls to separate functions (predefined in compile stage)
- Only transition on return (Restrictive if early return not implemented)
- Only allow if conditional branches are clear (Note: this would require early return to be implemented)

## Extended Example

## Semantics

### Errors/Warnings
- Check invalid characters in state definition
- State has to be specified if contract is stateful
- Check for attempting to become invalid states
- Warning if there are multiple becomes
- Check for code after return/become
- Check for invalid state specifications in restriction group
- Call functions without necessary state requirements
- Become after return is accepted
- Become can only use state enums for particular contract
- Incorrect ordering for become / return
- Becomes are mutating expressions
- Functions with becomes must be mutating
- Calls functions without necessary state requirements

### Unsafe Operations (Dynamic State Checking)
- On public functions/entrance functions state is checked
- If try is called on the function the state is checked beforehand dynamically (? - if return, ! - if revert)

## Possible future extensions

### Dynamic/multiple concurrent states
Could introduce multiple states being possible and the idea of sub-states. For instance imagine a main state transition of: `Unitialised -> Active -> Closed`. Then within `Active` you might have: `AwaitingUsers -> InProgress -> Return`. This could be implemented with more states but would lead to longer code and annotations

### Capability Functions for State
```
Bank @(any) :: (any) {
  func isActiveState(state: State) -> Bool {
      return activeStates.keys.contains(state)
  }
}
Bank @(isActiveState) :: caller <- (any) {
  @payable
  mutating func deposit(implicit value: inout Wei) {
    balances[caller].transfer(&value)
  }
}
```
