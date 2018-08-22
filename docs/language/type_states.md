# Type States

Flint introduces the concept of **type states**. Insufficient and incorrect state management in Solidity code have led to security vulnerabilities and unexpected behaviour in widely deployed smart contracts. Avoiding these vulnerabilities by the design of the language is a strong advantage.

In Flint, states of a contract are declared within capability blocks, which restrict which users/contracts are allowed to call the enclosed functions.
```swift
// Ahyone can deposit into the Bank iff the state is Deposit
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
