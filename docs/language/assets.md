# Currency and Assets
Flint supports special safe operations when handling assets, such as Ether. They help ensure the contract's state consistently represents its Ether value, preventing attacks such as TheDAO.

The design of the Asset feature is in progress, the FIP-0001 proposal tracks its progress. At the moment, the compiler supports the Asset atomic operations for the Wei type only.

An simple use of Assets:
```swift
contract Wallet {
  var owner: Address
  var contents: Wei = Wei(0)
}
​
Wallet :: caller <- (any) {
  public init() {
    owner = caller
  }
​
  @payable
  public mutating func deposit(implicit value: Wei) {
    // Record the Wei received into the contents state property.
    // Value is passed by reference.
    contents.transfer(&value)
  }
}
​
Wallet :: (owner) {
  public mutating func withdraw(value: Int) {
    // Transfer an amount of Wei into a local variable. This
    // removes Wei from the contents state property.
    var w: Wei = Wei(&contents, value)

    // Send Wei to the owner's Ethereum address.
    send(owner, &w)
  }
​
  public func getContents() -> Int {
    return contents.getRawValue()
  }
}
```
Another example which uses Assets is the Bank example.

A more advanced use of Assets (not supported yet):
```swift
contract Wallet {
  var beneficiaries: [Address: Wei]
  var weights: [Address: Int]
  var bonus: Wei
​
  var owner: Address
}
​
​
Wallet :: (any) {
  @payable
  mutating func receiveBonus(implicit newBonus: inout Wei) {
    bonus.transfer(&newBonus)
  }
}
​
// Future syntax.
Wallet :: (owner) {
  mutating func distribute(amount: Int) {
    let beneficiaryBonus = bonus.getRawValue() / beneficiaries.count
    for i in (0..<beneficiaries.count) {
      var allocation = Wei(from: &balance, amount: amount * weights[i])
      allocation.transfer(from: &bonus, amount: beneficiaryBonus)
​
      send(beneficiaries[i], &allocation)
    }
  }
}
```
