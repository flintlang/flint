# Introducing Assets

* Proposal: [FIP-0005](0005-assets.md)
* Author: [Daniel Hails](https://github.com/djrhails)
* Review Manager: TBD
* Status: **Awaiting Review**
* Issue label: TBD

## Introduction

Smart contracts can carry out sensitive operations, such as transferring currency to another account. We introduce the `Asset` trait which represents items of value (for example, currency such as Wei). Asset types support a restricted set of operations and have their own semantics.

Assets can be **transferred** from/to other Assets of the same type (for example, transferring Wei from one variable to another). By default, it is not possible to create an Asset from a raw type (such as an Integer), and they cannot be implicitly destroyed.

In the context of currency, smart contracts often use **state properties** to record information about the balance they possess. So far, making such properties accurately reflect the balance the contract actually possesses had to be done manually by the programmer. Oversights, such as forgetting to update a state property, might lead to inconsistencies between a smart contract's actual balance and its state properties' view. Asset types provide a **safe** way of handling currency in Flint.

Making `Wei` and other currency types implement `Asset` allow the contract's state to always **accurately** represent the actual contract's balance (by default). The type system enforces Wei transfers to be recorded in the contract's state. Adding Wei to a contract can be done safely through an `@payable` function.

```swift
// Wei implements Asset

contract Bank {
  var balances: [Address: Wei]
}

Bank :: account <- (balances.keys) {
  @payable
  mutating func deposit(implicit value: inout Wei) {
    // Omitting this line causes a compiler warning: the value received should be recorded.
    balances[address].transfer(&value)
  }

  mutating func withdraw() {
    // balances[account] is automatically set to 0 before transferring.
    send(account, &balances[account])
  }
}
```

## Motivation

Numerous attacks targeting smart contracts, such as ones relating to reentrancy calls, allow hackers to steal a current's Ether balance.

The following `Bank` contract records the `balances` of its customers, and implicitly assumes that the sum of all the balances reflects exactly the total amount of Wei the bank received. When supporting `withdraw` and `deposit` operations, the programmer needs to manually update the `balances` dictionary to reflect the changes.

In the following example, if any of the lines ⍺ or β were omitted, the contract's state wouldn't be accurately representing the total amount it has. Omitting line β is more dangerous: we would be sending Wei without recording it in our state. A customer could withdraw the same amount until the bank's balance is completely exhausted.

```swift
contract Bank {
  var balances: [Address: Wei]
}

Bank :: account <- (balances.keys) {
  @payable
  mutating func deposit(implicit value: inout Wei) {
    balances[account] += value // ⍺
  }

  mutating func withdraw() {
    send(account, balances[account])
    balances[account] = 0 // β
  }
}
```

The following Solidity contracts show how call reentrancy can result in contracts sending more Wei than they intended to. The `withdraw` function retrieves the balance of the given account, transfers it back, then sets it to 0. On line 13, an external call is performed using the low-level `call` function, attaching a Wei value. No function signature is specified, so the target’s fallback function is called. The vulnerability is exploited if the target’s fallback function calls back into `withdraw(address)`. Lines 11–13 will be executed again, without having set the recipient’s balance to 0. Vulnerable thus sends balance again, and the process repeats itself until the transaction’s gas is exhausted.

```javascript
contract Vulnerable {
  mapping(address => uint256) public balances;

  ...

  function withdraw(address recipient) public {
    uint256 balance = balances[recipient];
    recipient.call.value(balance)();
    balances[recipient] = 0; // Fix: place this line before the call.
  }
}

contract Attacker {
  uint256 public total; function () public payable {
    msg.sender.call(bytes4(keccak256("withdraw(address)")), this);
    total += msg.value;
  }
}
```

The vulnerability can be avoided by swapping the last two lines of the `withdraw` function.
A type system could help ensure a contract can't send more Wei than it intended to.

## Proposed solution

We aim for the Flint equivalent of the above contract to simply be:

```swift
contract Bank {
  var balances: [Address: Wei]
}

Bank :: account <- (balances.keys) {
  @payable
  mutating func deposit(implicit value: inout Wei) {
    // Omitting this line causes a compiler warning: the value received should be recorded.
    balances[address].transfer(&value)
  }

  mutating func withdraw() {
    // balances[account] is automatically set to 0 before transferring.
    send(account, &balances[account])
  }
}
```

We introduce the special standard library `Asset` structure trait and make `Wei` an instance of it. A Flint `Asset` represents an item of value (for example, currency).

Asset types go beyond normal traits by only supporting a restricted set of operations and have their own semantics.

### Compiler guaranteed properties
- No Unprivileged Creation. It is not possible to create an asset of non-zero quantity
without transferring it from another asset.
- No Unprivileged Destruction. It is not possible to decrease the quantity of an asset
without transferring it to another asset.
- Safe Internal Transfers. Transferring a quantity of an asset from one variable to another
within the same smart contract does not change the smart contract’s total quantity of the
asset.
- Safe External Transfers. Transferring a quantity `q` of an asset `A` from a smart contract `S`
to an external Ethereum address decreases `S`’s representation of the total quantity of `A` by
`q`. Sending a quantity `q'` of an asset `A` to `S` increases `S`’s representation of the total quantity
of `A` by `q'`/

### Definition
The asset trait is defined as follows:

```swift
struct trait Asset {
  associatedtype RawType

  // Create the asset by transferring a given amount of asset's contents.
  init(from other: inout Self, amount: RawType)

  // Unsafely create the Asset using the given raw value.
  init(unsafeValue: RawType)

  // Return the raw value held by the receiver.
  func getRawValue() -> RawType

  // Transfer a given amount from source into the receiver.
  mutating func transfer(from source: inout Self, amount: RawType)

  // CONVENIENCE FUNCTIONS //

  // Create the asset by transferring another asset's contents.
  init(from other: inout Self) {
    self.init(from: &other, amount: other.getRawValue())
  }

  // Transfer the value held by another Asset of the same concrete type.
  mutating func transfer(from source: inout Self) {
    transfer(from: &source, amount: source.getRawValue())
  }
}
```

As such the global send function would then become:

```swift
func send<T: Asset & EthereumCurrency>(destination: Address, asset: T)
```

## Assets backed by numeric raw values

For types which are backed by a numeric value, such as `Wei` or `Ether`, we define the `Numeric` and `Comparable` structure traits and implement a trait extension.

```swift
struct trait Numeric {
  infix func +(_ other: Self)
  infix func -(_ other: Self)
}

struct trait Comparable {
  infix func <(_ other: Self)
  infix func <=(_ other: Self)
  infix func >(_ other: Self)
  infix func >=(_ other: Self)
}
```

```swift
struct trait NumericAsset: Asset {
  associatedtype RawType: Numeric & Comparable

  mutating func transfer(from source: inout Self, amount: RawType) {
    if amount > source.getRawValue() { fatalError() }

    source.unsafelySetRawValue(source.getRawValue() - amount)
    unsafelySetRawValue(getRawValue() + amount)
  }
}
```

Wei is then defined as:

```swift
struct Wei: NumericAsset, EthereumCurrency {
  var rawValue: Int

  init(unsafeValue: Int) {
    rawValue = unsafeValue
  }

  init(from other: Wei, amount: Int) {
    rawValue = 0
    transfer(from: &other, amount: amount)
  }

  func getRawValue() -> Int {
    return rawValue
  }

  mutating func unsafelySetRawValue(_ value: Int) {
    rawValue = value
  }
}
```

## Semantics
At the heart of Assets are the built-in semantics that lead to compiler warning triggers.

### Single consumption
Compiler errors are triggered when asset local variables or parameters are not consumed exactly once in the scope of the function.

### Transferring an asset

The contents of an asset can be transferred to another asset like so:

```swift
// Transfer the contents of b into a, clearing b.
a.transfer(from: &b)
```

### Transferring a subset of an asset

```swift
// Transfer 50 from b into a.
a.transfer(from: &b, amount: 50)
```

### Warnings

#### Assignment between assets trigger warnings

```swift
var a = Wei(from: &b)
a = b // Warning: The contents of a are implicitly destroyed. Use transfer(from:) instead.
```

#### Use of assets after transfer

```swift
let a = Wei(from: &b)
let c = Wei(from: &b) // Warning: The contents of b have already been transferred in this scope.
```

#### Local variables which haven't been transferred exactly once

```swift
{
  let a = Wei(from: &b)
  // Warning: The contents will be lost as a has not been transferred in this scope.
}
```

### Unsafe operations

#### Creation from a raw value

```swift
let a = Wei(unsafeCreate: 50)
```

#### Destroying an asset

```swift
{
  let a = Wei(from: &b)
  a.destroy()
  // No warning.
}
```


### Unsupported operations

#### Assets as parameters

Functions cannot take asset parameters by value, as implicit copying of assets should be avoided.

```swift
func foo(a: Wei) {} // Error: Asset of type 'Wei' needs to be passed inout.
```

#### Functions returning assets

Functions cannot return assets.

```swift
func foo() -> Wei {} // Error: Cannot return type 'Wei' which conforms to 'Asset'.
```

### Branching

When branching is involved:

```swift
mutating func foo(out: inout Wei) {
  var x = Wei(from: &self.a)
  var z = Wei(from: &self.c)

  if x.getRawValue() == 2 {
    var y = Wei(from: &self.b)
    x.destroy()
    z.destroy()
    // Error: The contents of y will be lost as y has not been transferred in this scope.
  }

  out.transfer(from: &x)
  // Warning: The contents of z will be lost as y might not have been transferred in this scope.
}
```

### Impact on mutating functions

As usual, functions taking state properties as inout arguments are considered to be mutating.

```swift
func foo() {
  let x = Wei(from: &self.a) // Error: use of mutating statement in non-mutating function.
}
```

### Impact on external function call

It is not possible to declare a function taking `inout` parameters (required for Asset types)
with `public` visibility.

### Example: Withdrawing a specific amount

```swift
contract Wallet {
  var balances: [Address: Wei]
}

Wallet :: account <- (any) {
  mutating func withdraw(amount: inout Wei) {
    let retrieved = Wei(from: &balances[account], amount: amount) // Removes amount from balances[account].
    send(account, &retrieved) // Transfers retrieved.
  }
}
```

### Receiving currency

Functions annotated with `@payable` have an implicit parameter of type `Wei`, which is an `Asset`. This makes recording a transfer's value type-safe.

```swift
contract Wallet {
  var balance: Wei
}

Wallet :: (any) {
  @payable
  mutating func receive(implicit value: inout Wei) {
    balance.transfer(&value) // Safe
  }
}
```

### Example: Distributing money among peers

The following example distributes weighted amounts of Wei to a set of beneficiaries, attaching a split bonus as well.

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
    for i in (0..<beneficiaries.count) {
      var allocation = Wei(from: &balance, amount: amount * weights[i])
      allocation.transfer(from: &bonus, amount: beneficiaryBonus)

      send(beneficiaries[i], &allocation)
    }
  }
}
```

## Possible future extensions

### Special syntax

In the future, we should consider using the following syntactic sugar for the `Asset` operations.

### @autodestroying attribute

We should consider creating an `@autodestroying` function attribute, which would implicitly destroy local Asset variables at the end of every scope it defines.

```swift
@autodestroying
mutating func foo() {
  var x = Wei(from: &self.a)
  var z = Wei(from: &self.c)

  if x.getRawValue() == 2 {
    var y = Wei(from: &self.b)
    // y is implicitly destroyed
  }

  // z is implicitly destroyed
}
```

We need to find compelling use-cases for this feature.

### Implicit type conversions between compatible Assets

We should consider implicitly converting compatible Asset types when applicable.

```swift
// a has type Ether
let b = Wei(from: &a) // Convert a to its Wei correspondant and assign to b.
```

## Alternatives considered

Many alternatives were considered.

### Class-based approach

We could also implement assets using a class-based approach.

```swift
class Asset<T: Numeric> {
  var rawValue: T

  init(unsafeValue: T) {
    rawValue = unsafeValue
  }

  func getRawValue() -> T {
    return rawValue
  }

  mutating func transfer(from source: inout Asset<T>) {
    transfer(from: source, amount: source.getRawValue())
  }

  mutating func transfer(from source: inout Asset<T>, amount: RawType) {
    if amount > source.getRawValue() { fatalError() }

    source.unsafelySetRawValue(source.getRawValue() - amount)
    unsafelySetRawValue(getRawValue() + amount)
  }

  mutating func unsafelySetRawValue(_ value: T) {
    rawValue = value
  }
}

class Wei: Asset<Int> {
  init(from other: Wei, amount: Int) {
    rawValue = 0
    transfer(from: &other, amount: amount)
  }

  mutating func destroy() {
    unsafelySetRawValue(0)
  }
}
```

### Linear types

We considered implement the Asset trait as linear type. Local variables would have needed to be consumed exactly once in the scope they are defined. State properties however would only be able to be consumed at most once, making them affine types. These rules are however not enforcable for assets contained in arrays or dictionaries, due to aliasing issues. Instead, the compiler produces warnings whenever it can detect such cases.
