# Installation
---
## Docker
The Flint compiler and its dependencies can be installed using Docker:
```
docker pull franklinsch/flint
docker run -i -t franklinsch/flint
```
Example smart contracts are available in `/flint/examples/valid/`.

---
## Binary Packages and Building from Source
### Dependencies

#### Swift
The Flint compiler is written in Swift, and requires the Swift compiler to be installed, either by:
- Mac only: Installing Xcode (recommended)
- Mac/Linux: Using `swiftenv`
  1. Install swiftenv: `brew install kylef/formulae/swiftenv`
  2. Run `swiftenv install 4.1`

#### Solc
Flint also requires the Solidity compiler to be installed:

**Mac**
```
brew update
brew upgrade
brew tap ethereum/ethereum
brew install solidity
```
**Linux**
```
sudo add-apt-repository ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install solc
```

### Binary Packages
Flint is compatible on macOS and Linux platforms, and can be installed by downloading a built binary directly.

The latest releases are available at https://github.com/franklinsch/flint/releases.


### Building From Source
The best way to start contributing to the Flint compiler, `flintc`, is to clone the GitHub repository and build the project from source.

Once you have the `swift` command line tool installed, you can build `flintc`.
```
git clone https://github.com/franklinsch/flint.git
cd flint
make
```
The built binary is available at `.build/debug/flintc`.

Add `flintc` to your PATH using:
```
export PATH=$PATH:.build/debug/flintc
```

**Using Xcode**

If you have Xcode on your Mac, you can use Xcode to contribute to the compiler.

You can generate an Xcode project using:
```
swift package generate-xcodeproj
open flintc.xcodeproj
```

---
## Syntax Highlighting
Syntax highlighting for Flint source files can be obtained through several editors, including:
### Vim
By running the following command in the flint repository vim will now have syntax highlighting.
```
ditto utils/vim ~/.vim
```
### Atom
The `language-flint` package can be downloaded to have syntax highlighting for flint files.
