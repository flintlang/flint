# Ethl

Ethl is a new programming language designed for writing robust decentralized applications, or *smart contracts*. Currently, the Ethl compiler, `ethlc`, targets the Ethereum Virtual Machine.

## Declaring a contract

An `.ethl` source file contains contract declarations. A contract is declared by specifying its identifier, and property declarations. Properties constitute the state of a smart contract.

Consider the following example.

```
contract Bank {
	var manager: Address
	var accounts: [Address: Int]
}
```

This is the declaration of the `Bank` contract, which contains two properties. The `manager` property has type `Address`, and `accounts` is a dictionary, or mapping, from `Address` to `Int`.

## Specifying the behavior of a contract

The behavior of a contract is specified through contract behavior declarations.

Consider the following example.

```
Bank :: (any) {
	public mutating func deposit(address: Address, amount: Int) {
		accounts[address] += amount
	}
}
```

This is the contract behavior declaration for the `Bank` contract, for callers which have the `any` capability (explained in the next section).

The function `deposit` is declared as `public`, which means that anyone on the blockchain can call it.

`deposit` is declared as `mutating`, and has to be: its body mutates the state of the contract. Functions are nonmutating by default.

