# Types

## Data Types

Flint supports the following types.

### Basic Types
|Type      | Description             |
|----------|-------------------------|
|`Address` | 160-bit Ethereum Address|
|`Int`     | 256-bit integer         |
|`Bool`    | Boolean value           |
|`Void`    | Void value              |

### Arrays and Dictionaries
|Type      | Description             |
|----------|-------------------------|
| `Array` | Dynamic-size array. `[Int]` is an array of Ints |
| `Fixed-size Array` | Fixed-size memory block containing elements of the same type. `Int[10]` is an array of 10 `Int`s.         |
| `Dictionary` | Dynamic-size mappings from one key type to a value type `[Address: Bool]` is a mapping from `Address` to `Bool` |

### Ethereum-specific types
Uses cases for the following types is described into more detail in `Payable Functions and Events`.

|Type      | Description             |
|----------|-------------------------|
| `Wei` | A Wei value (the smallest denomination of Ether) |
| `Event<T...>` | An Ethereum event. Takes an arbitrary number of type arguments |
