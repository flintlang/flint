# Payable
On Ethereum, function calls to other contracts (i.e., "transactions") can be attached with an amount of Wei (the smallest denomination of Ether). Such functions are called "payable". The target account is then credited with the attached amount.

Functions in Flint can be marked as payable using the `@payable` attribute. The amount of Wei sent is bound to an implict variable:
```swift
@payable
public func receiveMoney(implicit value: Wei) {
  doSomething(value)
}
```
Payable functions may have an arbitrary amount of parameters, but exactly one needs to be implicit and of a currency type.

---
