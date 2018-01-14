# Data Types

Flint supports the following types.

## Basic types

| Type | Description |
| ---- | ----------- |
| `Address` | 160-bit Ethereum address |
| `Int`| 256-bit integer |
| `Bool`| Boolean value |
| `Void`| Void value |
| `Wei`| An Ethereum Wei (the smallest denomination of Ether) |

## Arrays and Dictionaries

| Type | Description |
| ---- | ----------- |
| Array | Dynamic-size array. <br> `[Int]` is an array of `Int`s |
| Fixed-size Array| Fixed-size memory block containing elements of the same type. <br> `Int[10]` is an array of 10 `Int`s. |
| Dictionary | Dynamic-size mappings from one key type to a value type <br> `[Address: Bool]` is a mapping from `Address` to `Bool` |

Note: A `[Int: T]` dictionary can be used as a dynamically-size array of element type `T`.
