# Compiler Guide

**Table of Contents**
- [Modules](#modules)
- [Tests](#tests)
- [Standard Library](#standard-library)
- [Documentation](#documentation)
- [Proposals](#proposals)
- [Examples](#examples)
- [Utils](#utils)

## Modules
The Flint compiler is separated into the following modules, all source files are contained within the `Sources` and each module has a directory of the same name that contains those files:
- [Source](#source) implements references to the Flint source code.
- [Diagnostic](#diagnostic) provides consistent errors, warnings and notes throughout the compiler for each of the different AST Passes.
- [Lexer](#lexer) decomposes the source code into tokens according to their contextual meaning. This is checked, in part, by [Parser Tests](#parser-tests).
- [Parser](#parser) takes the lexer outputted tokens and consumes them to construct the abstract syntax tree. This is checked by [Parser Tests](#parser-tests).
- [AST](#ast) contains anything related to the Abstract Syntax Tree (AST) and passes through it. Namely:
  - The nodes of the AST (`ASTNode.swift`, `TopLevelModule.swift`, `Component/`, `Declaration/`, `Expression/`, `Statement/`)
  - The AST framework for passes through the AST (`ASTPass/`, `ASTVisitor/`)
  - The environment which is used by each pass (`Environment/`)
  - The internal type system (`Type.swift`)
  - The dumper of the AST that is used for testing (`ASTDumper.swift`)
- [Semantic Analyzer](#semantic-analyzer) is an AST Pass that checks that the valid syntax (source code that matches the grammar) is meaningful and outputs diagnostics relating to that. This is checked by [Semantic Tests](#semantic-tests).
- [Type Checker](#type-checker) is an AST Pass that checks if the types are correctly paired throughout the program. This is checked by [Semantic Tests](#semantic-tests).
- [Optimizer](#optimizer) is a stub.
- [IRGen](#irgen) ouputs the intermediate representation of the program (currently [YUL (formerly IULIA)](https://solidity.readthedocs.io/en/latest/yul.html) assembly code embedded in a Solidity contract). This comprises of:
  - A preprocessing AST pass that modifies the AST to strip out any convenience syntax and mangle function names so that there are no conflicts. (`Preprocessor/`)
  - IR generation structures for AST Nodes (`IULIA*.swift`) which render the IR strings.
- [Lite](#lite) is the test runner.
- [File Check](#file-check) does a comparison of files. Used in [Parser Tests](#parser-tests).
- [flintc](#flintc) is the main module that controls the command line interface to pass to the Compiler (`Compiler.swift`) that coordinates all of the modules detailed above to generate the IR. It also preprends the source code of the [Standard Library](#standard-library) to the source code of the inputted files that is passed to the Solidity Compiler (`SolcCompiler.swift`).

---

## Tests
### Parser Tests (`Tests/ParserTests`)
The _Parser Tests_ are a series Flint files which test the production of the Abstract Syntax Tree.
Each parser test file is a `.flint` file which contains special comments of the form `// CHECK-AST: XXX` where `XXX` corresponds to a partial match of a line in the AST Dump of that program. Each file corresponds to a different aspect of the AST.

### Semantic Tests
The _Semantic Tests_ are a series of Flint files which test the diagnostic output of the compiler.
Each semantic test file is a `.flint` file which contains special comments of the form `// expected-XXX {{YYY}}` where `XXX` corresponds to either a `warning`, `error` or optionally `note` and `YYY` corresponds to the diagnostic message that is outputted by the compiler.
The semantic test files are compiled and the standard output is compared to these _expected diagnostics_ according to the `DiagnosticVerifier.swift` file. Any unexpected diagnostics or the absence of an expected diagnostic leads to a test failure for that file.

### Behavior Tests
The _Behaviour Tests_ are the most comprehensive tests run using _Truffle_; they use the fully compiled bytecode on a test blockchain and check they perform as expected. Each one is contained in a separate folder in the `tests/` subdirectory. They must contain:
- A `.flint` program to compile and deploy to the blockchain
- A `test/config.js` which specifies the contract name
- A `test/test/test.js` file which details the actual tests run against that particular contract.

Either use the `BehaviorTestTemplate` or one of the prexisting tests such as `array` to get a better understanding of how these function.

You can also use the [Truffle Reference](https://truffleframework.com/docs/truffle/testing/writing-tests-in-javascript) for writing these tests.

---

## Standard Library
The `stdlib` folder contains the Flint Standard Library which is special privileged flint code that can directly reference intermediate representation function calls and use `$` in identifiers.

These provide core types and language functionality that can be expressed in Flint.

---

## Documentation
The `docs` folder contains any documentation for Flint, in particular the Flint Language Guide (`language_guide.md`), this Compiler Guide (`compiler_guide.md`) and the grammar in Augmented Backus-Naur Form (`grammar.abnf`).  These should be updates along with any language features or compiler changes.

---

## Proposals
Contains all Flint Improvement Proposals (FIPs) which track the design and implementation of larger new features for Flint or the Flint compiler. An example is [FIP-0001: Introduce the Asset trait](/proposals/0001-asset-trait.md).

---

## Examples
The `examples` folder contains a few example Flint programs with basic functionality (`valid/`), solidity translations (`solidity-translations/`), some invalid code (`invalid/`), and future language examples (`future/`).

---

## Utils
- Snapshotting Code (`tag_snapshot.sh`)
- Vim integration (`vim/`)
