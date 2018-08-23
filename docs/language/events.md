# Events
JavaScript applications can listen to events emitted by an Ethereum smart contract.

In Flint, events are declared in contract declarations. The `Event` type takes generic arguments, corresponding to the types of values attached to the event.
```swift
contract Bank {
  var balances: [Address: Int]
  var didCompleteTransfer: Event<Address, Address, Int> // (origin, destination, amount)
}
​
Bank :: caller <- (any) {
  mutating func transfer(destination: Address, amount: Int) {
    balances[caller] -= amount
    balances[destination] += amount
​
    // A JavaScript client could listen for this event
    didCompleteTransfer(caller, destination, amount)
  }
}
```
