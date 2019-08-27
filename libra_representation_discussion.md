# Reflections on the task of implementing an internal Flint represantion for the Libra currency

## Wei vs Libra
In solidity, Wei is implicitly passed along with the transaction rather than being an argument to the contract method that the transaction calls. This is made clear in the Flint representation using Flint's `implicit`  parameter modifier and the `@payable` annotation which turn the money being passed in with the transaction into a contract's method argument that the Flint programmer can use inside the body of the method as they would with any other argument. So, internally, Flint's `Wei`s are just safe wrappers around integers.

This, however, cannot be the case for the representation of Libra inside Flint as, in Move, the parameters of a method that moves money around the blockchain are themselves safe wrappers around integers (i.e. instances of the `LibraCoin.T` resource). Hence, Libra in Flint must be either a safe wrapper (likely a struct that implements the `Asset` trait) around an instance of `LibraCoin.T` or a placeholder for `LibraCoin.T` that gets correctly replaced at the Move code generation stage. 

One of the consequences of this is that the current implementation of the `transfer` method for the `Asset` trait will not work on Libra as it relies on the ability to change the value of its internal integer representation through the `setRawValue` method, but no similar method is exposed by the move module `LibraCoin` for understandable safety reasons.

## Resources and values in Flint?

- Would such a distinction even be necessary or make sense at the Flint's level?

Unless absolutely necessary, we want to avoid changing the language as that would likely break currently working solidity translations and force us to split Flint into two versions (solidity and move), which is clearly undesirable.

## Is an implementation based exclusively on mutable references possible/sensible?
Currently, in Flint, structs must be passed by reference. This nullifies the possibility of calling, from inside the translated body of a contract method, a Move function that takes in a concrete resource rather than a reference to it as one of its arguments. For the specific case of Libra, however, this could be circumvented using the method provided by the `LibraCoin` module 
```rust
public withdraw(coin_ref: &mut Self.T, amount: u64): Self.T
```
which, given a mutable reference to some `LibraCoin.T` instance, generates a new `LibraCoin.T` instance with as much money as `amount` specifies, taking the necessary funds (assuming that they are available) from the resource that `coin_ref` points to. 

Then, it becomes trivial to safely generate concrete `LibraCoin` instances starting from a reference (say `coin_ref`) in the move translation of a Flint contract as follows 

```rust
generate_libra_instance(coin_ref: &mut LibraCoin.T): LibraCoin.T {
    let coin_value: u64;
    let ret: LibraCoin.T;
    coin_value = LibraCoin.value(freeze(copy(coin_ref)));
    ret = LibraCoin.withdraw(copy(coin_ref), copy(coin_value));
    release(move(coin_ref));
    return move(ret);
}

public any_func(coin_ref: &mut LibraCoin.T) {
    any_func_with_the_resource_as_argument(generate_libra_instance(move(coin_ref)));
    // ...rest of the body...
}
```
This would suggest that representing and using Libra from within Flint is possible just by operating at the code generation stage. However, such an implementation could be limiting in the general case when using external calls e.g. if some other Move module defines a resource type which cannot easily be generated starting from a mutable reference to another instance of that type.

## Libra implementation in the stdlib
Having enstablished that the Libra implentation based on passing mutable references is the one that we want to go for as it doesn't require changing Flint, and that such an implementation is viable. We start with a struct implementing the `Asset` trait that wraps around some `LibraCoin` type.

```swift
struct Libra: Asset {
  let coin: LibraCoin
  // ...initialisers and methods...
```
However, we are now left with the problem of defining the `LibraCoin` type. We could make `LibraCoin` just a special Move type within Flint that maps to the Move `LibraCoin.T` type, but that does not generalise very well to types defined by other Move modules. So, we need a way of importing a representation of `LibraCoin.T` Flint that is generalisable to other modules. Fortunately, Flint provides us with `external` traits, and external calls (*external calls refer to a Flint contract calling the functions of other contracts deployed on the Ethereum network*, Flint Programming Language Guide). Which would allow us to write the following
```swift
external trait LibraCoin {
    // functions made available by the module
}

struct Libra: Asset {
  let coin: LibraCoin
  // ...initialisers and methods...
```
However, external traits are not immediately usable on the libra blockchain as there is no concept of Move contracts, but just of Move modules. Thus, an implementation of Flint external traits that works with the libra blockchain is necessary before moving forward. 

---
## TO DO:
## Some hypothetical translation examples
This set of examples serves to investigate whether Libra can be handled correctly just by using mutable references, i.e. without changing the current Flint's constraint that structs can only be passed by reference.

## Wallet
---
Flint
```swift
contract Wallet {
    var money: Libra
}

Wallet :: (any) {
    public init() {}

    public func deposit(amount: inout Libra) {
        money.transfer(source: &amount)
    }
}
```
----
MoveIR
```rust
modules:
module Wallet {
    import 0x0.LibraCoin

    resource T {
        money: LibraCoin.T
    }

    public deposit(this: &mut Self.T, amount: &mut LibraCoin.T) {
       // Resolved by translation
    }
}
```