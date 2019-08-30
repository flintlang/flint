# Reflections on the task of implementing an internal Flint representation for the Libra currency

## Wei vs Libra
In solidity, Wei is implicitly passed along with the transaction rather than being an argument to the contract method that the transaction calls. This is made clear in the Flint representation using Flint's `implicit`  parameter modifier and the `@payable` annotation which turn the money being passed in with the transaction into a contract's method argument that the Flint programmer can use inside the body of the method as they would with any other argument. So, internally, Flint's `Wei`s are just safe wrappers around integers.

This, however, cannot be the case for the representation of Libra inside Flint as, in Move, the parameters of a method that moves money around the blockchain are themselves safe wrappers around integers (i.e. instances of the `LibraCoin.T` resource). Hence, Libra in Flint must be either a safe wrapper (likely a struct that implements the `Asset` trait) around an instance of `LibraCoin.T` or a placeholder for `LibraCoin.T` that gets correctly replaced at the Move code generation stage. 

One of the consequences of this is that the current implementation of the `transfer` method for the `Asset` trait will not work on Libra as it relies on the ability to change the value of its internal integer representation through the `setRawValue` method, but no similar method is exposed by the move module `LibraCoin` for understandable safety reasons.

## Is an implementation based exclusively on mutable references possible/sensible?
Currently, in Flint, structs must be passed by reference. This nullifies the possibility of calling, from inside the translated body of a contract method, a Move function that takes in a concrete resource rather than a reference to it as one of its arguments. For the specific case of Libra, however, this could be circumvented using the function provided by the `LibraCoin` module 
```rust
public withdraw(coin_ref: &mut Self.T, amount: u64): Self.T
```
which, given a mutable reference to some `LibraCoin.T` instance, generates a new `LibraCoin.T` instance with as much money as `amount` specifies, taking the necessary funds (assuming that they are available) from the resource that `coin_ref` points to. 
> I recommend you take a look at the methods provided by Libra's own stdlib for LibraCoin and LibraAccount at https://github.com/libra/libra/tree/master/language/stdlib/modules

Then, it becomes trivial to safely generate concrete `LibraCoin` instances starting from a reference (say `coin_ref`) in the move translation of a Flint contract as follows 

```rust
generate_libra_instance(coin_ref: &mut LibraCoin.T): LibraCoin.T {
    let coin_value: u64;
    let ret: LibraCoin.T;
    coin_value = LibraCoin.value(freeze(copy(coin_ref)));
    ret = LibraCoin.withdraw(copy(coin_ref), copy(coin_value));
    _ = move(coin_ref);
    return move(ret);
}

public any_func(coin_ref: &mut LibraCoin.T) {
    any_func_with_the_resource_as_argument(generate_libra_instance(move(coin_ref)));
    // ...rest of the body...
}
```
This would suggest that representing and using Libra from within Flint is possible just by operating at the code generation stage. However, such an implementation could be limiting in the general case when using external calls e.g. if some other Move module defines a resource type which cannot easily be generated starting from a mutable reference to another instance of that type.

# Libra implementation in the stdlib
## External traits?
Having established that the Libra implentation based on passing mutable references is the one that we want to go for as it doesn't require significant changes to Flint, and that such an implementation is viable. We start with a struct implementing the `Asset` trait that wraps around some `LibraCoin` type.

```swift
struct Libra: Asset {
  let coin: LibraCoin
  // ...initialisers and methods...
```
However, we are now left with the problem of defining the `LibraCoin` type. We could make `LibraCoin` just a special Move type within Flint that maps to the Move `LibraCoin.T` type, but that does not generalise very well to types defined by other Move modules. So, we would like a way of importing a representation of `LibraCoin.T` Flint that is generalisable to other modules. Flint provides us with `external` traits, and external calls (*external calls refer to a Flint contract calling the functions of other contracts deployed on the Ethereum network*, Flint Programming Language Guide). Which would allow us to write the following
```swift
external trait 0x123.LibraCoin {
    // functions made available by the module
}

struct Libra: Asset {
  let coin: LibraCoin

  public init() {
      // Having to provide an address doesn't make sense
      coin = LibraCoin(address: <some_address>) 
  }
  // ...other methods...
```
However, while external traits allow us to introduce a new external type inside Flint, they require the address of the published contract to be inserted upon initialisation. This makes no sense in the case of LibraCoin as it does not constitute a contract, but just a resource struct. Alas, it appears that the external trait option is not viable and that making `LibraCoin` a special type within Flint is necessary unless other new concepts are to be introduced to Flint.


## Special LibraCoin type based implementation proposal
Thus, with a special `LibraCoin` type that at the code generation stage gets turned into move's `LibraCoin.T`, we can go back to our initial `Libra` implementation attempt. Note that ideally the `LibraCoin` type should not be made available throughout Flint but just within the `stdlib`, exclusively to the end of providing an implementation for `Libra`
```swift
struct Libra: Asset {
  let coin: LibraCoin
  // ...initialisers and methods...
```
> Take a look at `stdlib/move/Asset.flint` to find the entire (currently incomplete) implementation attempt.

The specific implementations for the methods required by the `Asset` trait should then be doable within Flint by defining and using MoveRuntimeFunctions (under `Sources/MoveGen/Runtime/MoveRuntimeFunction.swift`) that operate on parameters of the Move's type `&mut LibraCoin.T` so that the corresponding Flint's arguments of type `&LibraCoin` can be passed to them.
> Take a look at `stdlib/evm/Global.flint` to see an example use case of runtime functions 

---
## @payable
Even though we now have a blueprint for correctly handling Libra within Flint in its MoveIR translation, we still lack a plan on how to get the money within a Flint contract in the first place.

This is a simple example of how it's normally done if targeting Solidity: 
```swift
contract Wallet {
    var balance: Wei = Wei(0)
}

Wallet :: (any) {
    @payable
    public func deposit(implicit amount: inout Wei) {
        balance.transfer(source: &amount)
    }
}
```
The `@payable` annotation is used by the preprocessor to initialise Flint's representation of Wei in the Solidity translation from the integer denoting the implicit (i.e. not actually a method argument) Wei amount attached to the transaction. 
> Take a look at `Sources/IRGen/Preprocessor/IRPreprocessor.swift` to see how it's done.

Such an annotation, along with the `implicit` modifier, allow a public function to take in a dynamic parameter (i.e. `amount: inout Wei`), which is otherwise not allowed within Flint.

When targeting Move, it doesn't make sense to use the `implicit` modifier as there is no money implicitly associated with the transaction: the money is an actual argument. So, an equivalent contract could be written as follows

```swift
contract Wallet {
    var balance: Libra = Libra(0)
}

Wallet :: (any) {
    @payable
    public func deposit(amount: inout Libra) {
        balance.transfer(source: &amount)
    }
}
```
> This syntax is currently not supported and would need to be implemented.

In this case, the `@payable` annotation should tell the preprocessor that the function declaration of the `deposit` method typed by the programmer is actually a lie, and that it should be changed before code generation to the following.

```swift
public func deposit(amount_coin: inout LibraCoin) {
    // note that in the move translation the type of amount_coin would be &mut LibraCoin.T
    let amount: Libra = Libra(&amount_coin)
    balance.transfer(source: &amount)
}
```
This is necessary because the outside world has no concept of Flint's `Libra` asset, which can then only be created starting from `LibraCoin.T` or, to play nicely with Flint's rule that structs can only be passed by reference, from `&mut LibraCoin.T`, which are understood by the entire blockchain.