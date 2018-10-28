# Swift Language Server

![travis-ci badge status](https://travis-ci.org/owensd/swift-langsrv.svg?branch=master)

Welcome to the Swift Language Server. This is a language server that aims to be a server
that can be used by any development tool that whishes to target Swift.

Currently it provides the following interfaces to interact with it:
  - An implementation of the [Language Server Protocol][1]. This is a protocol that aims to be a
    common interface for developer tools put for by Microsoft, especially with regards for use
    within [Visual Studio Code][2].

## Future plans
  - Once the LSP is fully implemented, other interfaces will be looked into as well. Already,
    the JSONRPC mechanism will add overhead in the system that isn't quite necessary, but it does
    provide an easier interface to use.

## Design Breakdown

The system is broken up into parts that are designed to be interchangeable. Each layer of the
system is agnostic of the other layers, except for the data contracts that between each layer.

At a high level, the language server responds to commands that are passed into an implementation
of a `MessageSource` class. That data is processed and passed along to a `MessageProtocol`
implementation. From here, the data is parsed and turned into commands that can then be passed
on to a `LanguageServer` instance.

## Releasing

Before publishing a new release, it's important to have a clean CI build, the appropriate version
set in `VersionInfo`, and a matching tag. Only the release bits should be published. Once that is
all locked down, simply run `make publish`. A new release will be pushed up to GitHub.

BE CAREFUL! All release will be immediately available for others to download and use. This project
makes use of [semantic versioning][semver]. As such, some tools may automatically pick up new
versions based on `PATCH` version changes.

> Copyright (c) Kiad Studios, LLC. All rights reserved.
> Licensed under the MIT License. See License in the project root for license information.

[1]: https://github.com/Microsoft/language-server-protocol
[2]: https://code.visualstudio.com
[semver]: http://semver.org