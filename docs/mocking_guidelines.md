# Mocking Guidelines

Mocks are a valuable tool to have in your toolbox for writing effective tests as they help you test the behaviour of a single unit while stubbing the implementation of all other public methods.

As Swift does not have run-time reflection we are using our custom fork of [Cuckoo](https://github.com/flintrocks/Cuckoo) which adds Swift package manager support and renames Cuckoo's `SourceLocation` which conflicts with our own.

## Design Considerations

When using mocks, we need to fundamentally change the design of our application in order to mock. The most important of these is *dependency injection*. Rather than having a single global singleton instance, we should initialise dependencies that we need globally at the start of the program and pass these around as state. This way we can initialise objects in tests with a simulated environment to interrogate only the behaviour of that unit. In addition, static methods should not be used as they cannot be stubbed.

When you encounter a piece of old code that you wish to test, you are **strongly encouraged** to convert it to use a dependency injection style. Dependency injection works best when used globally.

Again, other languages that are prevalent in industry make dependency injection easy because they support mocking. This is not the case in Swift and therefore we have to again roll our own. With dependency injection, please try to keep down the number of dependencies required in a unit. If you have a large number of dependencies, your unit is probably too big.

We have two initial tickets, [#79](https://github.com/flintrocks/flint/issues/79) and [#80](https://github.com/flintrocks/flint/issues/80) to get most of the initial refactoring work out of the way.

## Organisation

Flint is organised into modules, which make testing the entire compiler slightly easier as there is already a separation of responsibilities and a sense of modularity.

We propose the following rules:
1. Each module has its own test package.
2. Each unit should have its own test file.

## Making things work

Because XCTest is not natively supported on Linux, please make sure you modify:
1. the global `Tests/LinuxMain.swift` file *if adding a new module*,
2. a module's `XCTestManifests.swift` file *if adding a new unit*,
3. a unit's `allTests` property *if adding a new test case*.

## Structure Protocols
Although this pattern should fall out of tickets [#79](https://github.com/flintrocks/flint/issues/79) and [#80](https://github.com/flintrocks/flint/issues/80), it is worth mentioning it again.

Cuckoo is unable to mock structures by default. We need to define protocols that have interfaces identical to any structure that we wish to mock, and replace any reference to the structure type with the protocol.

Static methods should be converted to methods of a singleton object, which means that we can set this object as the default implementation when we open units for dependency injection.

## Generating Mocks
We are working on streamlining the process of generating mocks. For now, Cuckoo is downloaded as part of the Swift package checkouts and we then require a manual invocation of the `generate_mocks.sh` bash script. This bash script will build the generator using Swift Package Manager and will then generate mocks.

We currently do not streamline the mock generation and suggest to only run it when objects are modified.