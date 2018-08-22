# Caller Capabilities

Flint introduces the concept of **caller capabilities**. While traditional computer programs have an entry point (the _main_ function), smart contracts do not. After a contract is deployed on the blockchain, its code does not run until an Ethereum transaction is received. Smart contracts are in fact more akin to RESTful web services presenting API endpoints. It is important to prevent unauthorized parties from calling sensitive functions.

In Flint, functions of a contract are declared within caller capability blocks, which restrict which users/contracts are allowed to call the enclosed functions.
```swift
// Only the manager of the Bank can call "clear".
Bank :: (manager) { // manager is a state property.
  func clear(address: Address) {
    // body
  }
}
```
Caller capabilities can be any property declared in the contract's declaration, as long as their type is `Address` or `[Address]`.

Note: The special caller capability any allows `any` caller to execute the function in the group.

Calls to Flint functions are validated both at compile-time and runtime.

---

## Static checking
In a Flint function, if a function call to another Flint function is performed, the compiler checks that the caller has sufficient caller capabilities.

Consider the following example.

```swift
Bank :: (any) {
  func foo() {
    // Error: Capability "any" cannot be used to perform a call to a
    // function for "manager"
    bar()
  }
}
​
Bank :: (manager) {
  func bar() {}
}
```
Within the context of `foo`, the caller is regarded as any. It is not certain that the caller also has capability manager, so the compiler rejects the call.

---
## Dynamic checking
#### Attempt function calls
It is still possible for the caller of `bar` to have the capability `manager`.

For these cases, two additional language constructs exist:

- `try? bar()`: The function `bar`'s body is executed if at runtime, the caller's capability matches `bar`'s. The expression `try? bar()` returns a boolean.
- `try! bar()`: If at runtime, the caller's capability doesn't match `manager`, an exception is thrown and the body doesn't get executed. Otherwise, it does.

Note: this is not supported by the compiler yet.

#### Calls from Ethereum users or non-Flint smart contracts
Functions to contracts on the Blockchain can also be called by users directly, through an Ethereum client, or another non-Flint smart contract.

For those cases, Flint checks at runtime whether the caller has the appropriate capabilities to perform the call, and throws an exception if not.

### Multiple capabilities
A contract behavior declaration can be restricted by multiple caller capabilities.

Consider the following contract behavior declaration:
```
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {}
}
```
The function `forManagerOrCustomers` can only be called by either the manager, or any of the accounts registered in the bank.

Calls to functions of multiple capabilities are accepted if **each** of the capabilities of the enclosing function are compatible with **any** of the target function's capabilities.

Consider the following examples:

#### Insufficient capabilities
```swift
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Error: "accounts" is not compatible with "manager"
    forManager()
  }
}
​
Bank :: (manager) {
  func forManager() {}
}
```
#### Sufficient capabilities
```swift
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Valid: "manager" is compatible with "manager", and "accounts" is
    // compatible with "accounts"
    forManagerOrCustomers2()
  }
}
​
Bank :: (accounts, manager) {
  func forManagerOrCustomers2() {}
}
```
#### `any` is compatible with any capability
```swift
Bank :: (manager, accounts) {
  func forManagerOrCustomers() {
    // Valid: "manager" is compatible with "manager" (and "any", too), and "accounts"
    // is compatible with "any"
    forManagerOrCustomers2()
  }
}
​
// The caller capability "manager" has no effect: "any" is compatible with any capability
Bank :: (manager, any) {
  func forManagerOrCustomers2() {}
}
```
#### Static and dynamic checking
Just like single-capability definitions, capability lists are checked both at compile-time and runtime.

---

## Capability Binding
Capabilities can be bound to temporary variables.

Consider the following example.
```swift
Bank :: account <- (accounts) {
  // This function is non-mutating
  public func getBalance() -> Int {
    return balances[account]
  }
​
  public mutating func transfer(amount: Int, destination: Address) {
    balances[account] -= amount
    balances[destination] += amount
  }
}
```
`withdraw` can be called by any caller which has an account in the bank. The caller's address is bound to the variable `account`, which can then be used in the body of the functions.
