# The State of Flint
_by Matteo Bilardi and Matthew Ross Rachar_

### Purpose
This report covers the state of the Flint programming language─what has been implemented, how things are done, the current known issues, and any likely problems that might arise and have not been thoroughly investigated. It has been written in the hope that future developers may start with a better understanding of the project, and not waste as much time worrying about things that are broken.

### Contents
- Configuration
  - Installation
    - Dependencies
  - Testing
  - Development
    - Operating system
    - IDE
    - Flint programming
- Implementation
  - History
    - Flintpath
    - Mutating _vs._ Mutates
    - Verifier Type Properties 
  - Move Translation
    - Reference Handling 
    - Programme Layout
    - Constructors
    - External Traits
    - Money
    - Resource and Struct Kinds 
  - Verifier
    - Shadow Variables
    - Predicates
  - Targets and the Compiler
  - Docker
  - Extensions
    - Gas Analyser
    - REPL
    - Testing Framework
    - Contract Analyser 
    - Syntax Highlighter
    - Flint Block
- Known Issues
  - Verifier
     - Types
     - External Checks
     - Invariants and Instantiation
     - Move
   - Move
     - Types Named T
   - Extensions
- Likely Problems
  - Method Resolution
  - Libra Updates
- Future
  - Verifier Macros 
  - Geth _vs._ Ganache

## Configuration
### Installation
Installation of Flint can still be quite complex, not only due to the number of dependencies that it has, but also down to specific version requirements, especially for the test-suite and extensions. The [official instructions](https://github.com/flintlang/flint/blob/master/docs/language_guide.md#building-from-source) for building from source in the language documentation have been updated to reflect the current installation process, and so we shan't elaborate too much on the basics here. We do suggest you follow them closely, any deviation can cause things to fail later that you mightn't expect. Also note Flint only supports Linux and Mac, and that we've only tried it on Ubuntu 18.04, macOS 10.14.4, and Arch Linux.

_Note that we're going to cover the necessary dependencies for someone working on Flint, not someone using it. We believe the online instructions should be sufficient for people who wish to just use flintc_

_**Note about Ubuntu 18.04 LTS**: If you're running Ubuntu 18.04, you should be able to run `
bash <(curl -s https://raw.githubusercontent.com/flintlang/flint/master/utils/install_ubuntu_18_04.sh)` to install all the required runtime dependencies. For testing you'll still need to run `npm install -g truffle@4`_

#### Dependencies
Make sure to install all the dependencies before installing Flint. The following advice has been provided for each one:

 - **Swift**: The  `.swift-version` files should tell Swiftenv _(see below)_ what version of swift should be run, if you install 5.0.2 and 4.2 on your system you should be okay, and there shouldn't be much of a issue updating the main Swift version to a slightly newer version, however, 4.2 is required for the test-suite, _(only, you can get away without it if you don't run any tests)_ Cuckoo, and would require working on updating the fork of Cuckoo that Flint relies on to Swift 5 to make Flint entirely dependent on only one version of Swift.
 - **Swiftenv**: We were working with Swiftenv 1.4, but the version of Swiftenv shouldn't matter. What's more important is that Swiftenv is set-up to be in control of `swift` terminal commands, so that as one dependency still runs on Swift 4.2, it can switch to that as is needed.
 -  **Mono**: Mono isn't required for any Flint project code, however is necessary for the Boogie and Symbooglix dependencies to run Flint's built-in verifier. Make sure you download the `mono-devel` as it's necessary to build Boogie and Symbooglix.
 - **NodeJS and npm**: Much of the flint ecosystem, due to it working with Ethereum, is built on NodeJS. From the testsuite to the extensions it's quite important that you have it installed.
 - **Swiftlint**: Only necessary as part of the testsuite, please note that it does get updated, and code that may've been fine when we left it might fail linting checks when you start work. We were using version 0.35.0

### Testing
To run tests you'll need truffle, specifically version 4. To install it, run `npm install truffle@4`.

### Development
Setting up an environment to work on Flint effectively can be troublesome, so we advise that you take the following seriously to avoid future issues 

#### Operating System

Unfortunately, although Swift is officially compatible with both macOS and Linux, there are sometimes differences in what works, builds and runs, that means its necessary to be vigilant about keeping Flint working on both operating systems. To that end, we advise that if you're working in teams, that you have people working on ***both*** systems. Obtaining the sudo permissions and the macOS version (>= 10.14.4) to get a lab Mac working can be challenging─CSG isn't in control of them, ICT is so you'll find this time consuming at best─but if one of you does own a Macintosh, that'd make things easier. 

#### IDEs

On Mac, just use XCode, it's designed for Swift and works fine. On Linux, try CLion because it does provide a decent level of inspection and information, although be warned: it doesn't work perfectly, and you may very easily find that the Swift extension causes it to crash (we've had this happen on some computers, and not on others, best of luck is all we can say).

#### Flint Programming

If you're writing Flint (as in `.flint` files), we advise VSCode. I get it: you're a fan of _X_ and don't want to deal with a different editor. Fine, but all of the extensions and tools have been built for it. If you have the time to build equivalent extensions for _X_, then go ahead, that'd be great, but if you don't you'll find that VSCode does what you need. Right now the following interface with VSCode

 - Flint Colour (available on the Marketplace)
 - Flint Language Server

## Implementation

### History

Unfortunately, as Flint has been worked on for some years now, it comes with a bit of history that may leave some things today a little confusing. To make sure you don't come across a term or system that doesn't make sense with the current state of Flint, we've compiled a list of explanations of old, removed concepts

#### Flintpath

When we received the project, we were faced with something that couldn't run. This was down to absolute paths (_/Users/_ NAME _/Documents/Projects/..._) being used across the programme by some of the previous developers, meaning it would work on their and only their machine. To solve this without using the unpredictable `#dsohandle`, which would be highly dependent on where the binaries were built (and thus on the IDE), we instituted a `$FLINTPATH` environment variable, which stored the root of the Flint directory. This allowed any part of the programme to easily know where to look for other files. Also note that Swift doesn't really allow for relative paths (`./path`), thus necessitating these solutions.

`$FLINTPATH` has since been removed by always placing Flint within `~/.flint` (which is similar to how cargo and cabal organise their system). We would advise looking at how other code handles filepaths before replacing anything you see that may still refer to a Flint path. In particular, you should look at `Sources/Utils/Path.swift` and `Sources/Utils/Configuration.swift`.

#### Mutating _vs._ Mutates

Historically, Flint used the same `mutating` keyword that Swift uses, for basically the same purpose, to declare that the method would mutate the instance it's defined on. However, with the advent of the verifier, it seems to have been decided that this wasn't specific enough, and that better verification could be provided by saying exactly which variables needed to be mutated _(see Verifier type properties for issues with the system they introduced)_. However, you may find in some places the word "mutating" is still used instead of mutates, especially for compiler variable names describing what is mutating. Also note the `isMutating` properties which still indicate whether the function is mutating any variables at all, a hangover of the old `mutating` keyword.

#### Verifier Type Properties

Today, the `mutates(...)` modifier on functions takes in the list of instance properties on that contract or struct that are to be mutated. However historically it took in the type properties that were being mutated, irrespective on the instance those type properties were defined on. For more information of this change, see [PR#467 Mutates on instance properties](https://github.com/flintlang/flint/pull/467) to find out: what was wrong, why it was a problem, and what was done to fix it. 

It does mean that today there are few restrictions on what you can put in a `mutates(...)` clause─you can basically put any identifier you want in there for backwards compatibility─all the semantic analyser will do is check what you actually do mutate is in the list (not the other way round).

### Move Translation

The entire Move translation system was built by us, although it is closely based and copied from the similar EVM translation system, to avoid replicating pre-existing infrastructure, to cut down on time, and to keep some homogeny across the compiler. For different information than is provided here, see [PR#476 Move](https://github.com/flintlang/flint/pull/476), which covers what the purpose of the features are, rather than what impact it has for future developers.

#### Reference Handling

Whilst Flint just provides straight-up types, only having a pass-by-reference argument system for structs, Move relies on strict reference control. To handle this disparity, we've had to create a system that references, copies and release objects in as controlled a way as possible. However, it's quite possible that this system might break down in some cases we've not thought of or tested, as it relies on references and copies thereof being made as locally as possible and nothing getting in the way. It should however try to ensure:

- References are copied and released correctly
- Local references (on one liners) are released as soon as possible
- Multiple borrows are prevented by being pulled out and handled together
- Unreferenced types are referenced as necessary

#### Programme Layout

As Move doesn't use the same contract-based system that Flint and Solidity follow, we had to find some way of providing a reasonable model for it in Move's module system. Move favours calling the main type of a module `T`, so our translation creates a module with the name of the contract, and an internal resource type `T` to store contract state.

To provide a way of publishing a new module, we provide the `publish(...)` method which can be called by other MoveIR code to publish a resource at the senders address. Also different to Solidity is that resources exist at user addresses, rather than at their own, so MoveIR flint contracts can only be published at the address of the sender.

All contract behaviour functions are provided with a wrapper function which takes in the address of the contract to be dealt with and acquires the resource there. We cannot just provide a get method that returns the resource or a reference to it as this is prevented by Move's own verification pass. These wrapper methods also ensure that the caller is allowed _(caller protections)_ and the contract's in the right state _(type state protections)_. Internally, the original method is called as the semantic analyser should defend against bad calls within a Flint programme.

#### Constructors

Move doesn't have classes, and doesn't have self. To make a new type, you pack it, similar to a record in some languages, or tuples in Python. Thus, to construct a type, you need to know what all the values of that type are to be. However, as Move doesn't have null, we can't really fill in the values (especially as they could be structs themselves) with anything until we now what the values should be.

To solve this we provide an individual variable for each property which the Move programme uses until all of them have been assigned. If that's the end of the function, it'll straight up return an instance to them. However, if it isn't, it'll assign the instance to a hidden variable, and assign self to a reference to that instance. This means the rest of the constructor can act like a normal function. It also means that other methods cannot be called from a constructor until all fields have been initialised, as there would be no self value to pass in as the first argument to the Move module functions.

#### External Traits

External traits provide a way of interfacing with the rest of the target language, in this case, they provide a way of dealing with contract-like Move modules. The basic requirement on a Move module that Flint is to interface with is that the methods describe in the external trait declaration must be in the same format as a Flint contract, taking in the address as the first argument. This is essential as Flint doesn't _(and shouldn't)_ parse Move, so that doesn't know what else to expect. Also, the address is all that is stored by the Flint programme to keep track of the resource in question _(`MyContract(address: 0xd3ad) ==> 0xd3ad`)_.

This difference between modules and contracts also mean one further difference, whilst Ethereum stores state and behaviour at one address (the one provided in the external trait constructor), Move uses two, one for the module (the original publisher) and one for the resource, the instance of the contract (the resource). To allow this to be specified, we introduced external trait attributes in [PR#477 External trait attributes](https://github.com/flintlang/flint/pull/477) which mean the modules address can be specified once when the trait is declared, using `@module(address: ...)`.

However, Flint also needs to interface with straight-up Move structs as data within the programme, not just modules. Hence, we broke one of the rules. The cops are after us, and we're on the run. Move external traits can only deal with external types. We said "no" because we needed external traits to take in a produce Move structs to be able to handle concepts like money. Thus we introduced `@data` and `@resource` to allow us to describe the interface with Move types. Underneath, external traits with the `@data` attribute are handled quite differently, much more like Flint defined structs.

#### Money

Right now LibraCoin isn't properly implemented in Flint. There is a test, "externaltraits-libra" which demonstrates and ensures it is possible to deal with money in Flint, however, there is no standard library implementation. This is something which should be relatively simple to fix, however, we ran out of time before we had to clean up to make Flint usable for the next team.

#### Resource and Struct Kinds

You'll notice under the type system in the MoveIR syntax model there are two separate cases for resources and structs. This may seem a little overkill today, as in Move they currently appear to be the same. This is sort of a hangover of the days when in Move they were handled differently (you had to declare the kind each type using `R#` for resources and `V#` for structs) however, it's still important as underneath they are, and because we need slightly different translation strategies for each. 

### Verifier

The verifier provides formal verification for Flint programmes. It is currently disabled on Move targeted compilations, but is by default enabled for Solidity compilation.

#### Shadow Variables

To allow a whole host of information about collections, shadow variables containing information about keys and length allow the verifier to keep track of their state. Note that the depth of the shadow variable is to do with multidimensional collections inner and outer collections.

#### Predicates

The verifier allows `pre`  and `post`conditions, contract `invariant`s and `assert`ions, the last of which are also compiled into runtime checks in the output code. Predicates may only contain a subset of Flint syntax, only allowing functions and simple binary operations to be put in them. Note that some of the predicate syntax might seem a little strange, such as passing in types, and argument identifiers being variable declarations, but this is necessary without a major rewrite of the predicate syntax to allow a more natural declaration system. This was not a priority for us so we've left it as is (although we added `forall` and `exists` predicates).

### Targets and the Compiler

Historically Flint had only one target, the EVM, so a lot of the overarching Compiler module, which is in charge of starting each other phase, had to be reorganised around a system of targets, with different aspects being target dependent. However, a lot of extensions are still EVM dependent, so you may notice it being used as the default target in some places. To compile to Move specifically, use the `--target move` flag.

### Docker

Currently there is a mantained Dockerfile within Flint's repo to reliably build Flint on other platforms through an ubuntu docker container. The instructions on how to use it are in the language guide. Note that there is docker image of flint currently published on Docker Hub (https://hub.docker.com/r/franklinsch/flint), however this version is not mantained and must not be used for development or usage of Flint. 

### Extensions

@matteo

## Known issues

### Verifier

#### Types

Right now the verifier cannot deal with strings. Any code that uses them must use the `--skip-verifier` flag to bypass the verifier.

#### External Checks

Although the verifier can check that the preconditions are met for any internal function call, it has to assume they are for any function call from an external source. This is a noticeable vulnerability, a programme that the verifier says is okay might have a input value defended against by the precondition that causes it to give all its money to the sender, and thus "verified" doesn't actually mean safe.

The two solutions to this would either be not to allow preconditions on public contract methods, or to ensure those preconditions were met with implicit defensive programming, failing and reverting if they aren't.

#### Move

Move doesn't work right now with the verifier, thanks to some of the special cases the verifier tries to handle involving Wei and Ethereum. Work would need to be done to get the verifier to reliably work with Move, but for now, the verifier is skipped if the target is Move/

#### Invariants and Instantiation 
@matteo

### Move

As the Move target is quite new, there may still be many undiscovered issues we don't know about with the Move translation. It passes the test-suite we provide (and much more) at the time of writing, and so we believe it should be sound enough for most uses cases.

#### Types Named T

As the Move translation uses a `resource T` to store contract state, as is convention on Move, it doesn't currently allow Flint types to also be called T. This should be a simple fix of name mangling, but it has yet to be implemented.

### Extensions
@matteo

## Likely Problems

### Method Resolution

Method resolution appears to be on what function names are in the local static scope at times, rather than strictly going on static type analysis. This was most noticeable when implementing external traits which handle structs, as they only work if a method has the same signature in the environment (and it can only have one argument it would seem) 

### Libra Updates

Unfortunately, Libra is (or was at the time of writing) still in early development, so their constant changes have resulted in us having to keep pace. By the time you're working on this, it is easily possible that a breaking change has meant that the Flint Move tests no longer pass. Our best advice would be to look through the changes to Libra's functional tests for the language, as these will show what they've had to change to keep their own tests passing, which should be a rough guide for fixing the issue.

## Future Work

### Verifier Macros

To allow Flint to express more expressions more easily in its verification predicates, we're suggesting a system of verifier "macros" which allow a whole host of built in functions to be declared, and for users to declare new ones, in a maintainable and generalised way.

### Geth _vs._ Ganache
Currently, part of the ecosystem of extensions developed and currently mantained for Flint rely on a local `geth` blockchain running in the background. This is not ideal as it's rather  