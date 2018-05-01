# Rename the term "caller capabilities"

* Proposal: [FIP-0002](0002-rename-caller-capabilities.md)
* Author: [Franklin Schrans](https://github.com/franklin_sch)
* Review Manager: TBD
* Status: **Awaiting review**
* Issue label: not yet

## Introduction

The term "caller capabilities" has been used to refer to the mechanism which ensures functions of a
Flint contract can only be called by a specific set of users. In particular, we say the caller of a
function must have the correct "caller capability" in order to be able to call a function. This term
might be however confusing, as the term "capability" is used differently in other languages which
feature "capabilities". The key difference is that capabilities are usually _transferable_, where
Flint caller capabilities are not. We propose renaming caller capabilities to **caller identities**.

## Motivation

Programming languages such as [Pony](http://ponylang.org) use the term ["reference
capabilities"](https://tutorial.ponylang.org/capabilities/reference-capabilities.html) to express
access rights on _objects_. In Flint, caller capabilities express access rights to _functions_.
However, the term "capability" usually refers to _transferable_ access rights. This means that if an
entity is allowed to access a resource, it should be able to transfer that right to another entity.
[Mark Miller et al.](http://srl.cs.jhu.edu/pubs/SRL2003-02.pdf) describe four security models which 
make the distinction between _Access Control Lists (ACLs)_ and different types of _capabilities_.
Flint caller capability would actually fit under _Model 1. ACLs as columns_.
Some definitions regard a capability as an _unforgeable token_, i.e., a bit string which when
possessed by a user, allows access to a resource.

Flint caller capabilities in fact implement something more similar to  Role-Based Access Control
(RBAC). RBAC based systems restrict certain operations to sets of users, through _roles_: if a user
has the appropriate role, it is allowed to perform the operation. In Flint, functions can only be
called if the user has the appropriate role.

In the following example, `clear(address:)` can only be called by the user which has the Ethereum
address stored in the `manager` state property.

```swift
contract Bank {
  var manager: Address
}

Bank :: (manager) {
  public func clear(address: Address) {
    // ...
  }
}
```

However, the manager's right to call `clear(address:)` is non-transferable, i.e., it cannot be
delegated to another Ethereum user. Hence referring to `address` as a caller capability is wrong 
under the classical definition of the term "capability".

## Proposed solution

We suggest the term **caller identity**. It clearly portrays that the determination of whether a
caller is allowed to call a function is based on an _identity_ check. Naturally, identities cannot
be transferred, and this term better describes Flint's mechanism.

We'll say a caller is allowed to call a function if it has an appropriate **caller identity**, or
simply an appropriate _identity_, rather than a _capability_.

The error message related to invalid function calls due to incompatible caller identities would be
updated:

```swift
Bank :: (any) {
  func foo() {
    // Error: Function bar cannot be called by any user
    bar()
  }
}

Bank :: (manager) {
  func bar() {
  }
}

Bank :: (manager, admin) {
  func baz() {
    // Error: Function bar cannot be called by all users in (manager, admin)
    bar()
  }
}

Bank :: (admin) {
  func qux() {
    // Error: Function bar cannot be called by admin
    bar()
  }
}
```

## Alternatives considered

The term _role_ was also considered instead of _identity_. I personally prefer "caller identity" 
than "caller role", and "requiring to have a specific identity to call a function" than "requiring 
to have a specific role". I am open to discussion for using "role" instead.

## Thank you

Thank you Mark Miller for bringing up the incorrect use of the term, and for suggesting Flint's
mechanism is closer to RBAC-based systems.
