This guides you through installing Flint in its current state on Linux

**Contents**
1. Prerequisites
2. Installation
3. Docker
4. Usage

## Prerequisites
The following must be installed to build Flint:
* mono 5.20 or later (C# 7.0)
* swiftenv
* clang
* nodejs npm

### Additionally for testing
To run the testing libraries, install:
* truffle 4

### On Ubuntu 18.04 LTS
This assumes a standard Ubuntu build with `apt`, `wget`, `curl`, `gnupg`, `ca-certificates` and `git` installed. If you don't have one of them installed, you should be notified during the process. If you have any kind of error, try installing them. Note Ubuntu 16.04 has different installation procedures when using apt and installing Mono, thus amendments will need to be made to this process.
```bash
sudo apt install nodejs npm clang

# Mono - https://www.mono-project.com/download/stable/
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" \
  | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
sudo apt update
sudo apt install mono-devel

# Swiftenv - https://swiftenv.fuller.li/en/latest/installation.html
git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bash_profile
echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(swiftenv init -)"' >> ~/.bash_profile
```

## Installation
In your terminal, run the following commands
```bash
# Use -jN for multi-core speedup (N >= 2)
git clone --recurse-submodule https://github.com/flintlang/flint.git
cd flint
# No need iff swiftenv has already installed relevent swift version or not using swiftenv
swiftenv install
swift package update
# Create a FLINTPATH for the compiler to run (this may be removed in a future version)
echo "export FLINTPATH=\"$(pwd)\"" >> ~/.bash_profile
source ~/.bash_profile

make
```

## Docker
To run the environment without doing any package installations:
```bash
git clone --recurse-submodule https://github.com/flintlang/flint.git
cd flint
sudo docker build -t "flint_docker" .
### ---------------------------------------------- ###
# Docker will build, this process may take some time #
### ---------------------------------------------- ###
sudo docker run --privileged -i -t flint_docker
# Then, inside the docker container, run
source ~/.bash_profile
```

## Usage
To use flint to compile a flint contract (in this example `counter.flint`) into solidity code run the following code from inside the flint project folder:
```bash
export FLINTPATH=$(pwd)
export PATH=$FLINTPATH/.build/debug:$PATH
flintc --emit-ir --ir-output ./ examples/valid/counter.flint
```
This will generate a main.sol file inside the current directory which can then be compiled to be depolyed on the Etherum blockchain. To test it, we recommend using Remix IDE, following these instructions https://docs.flintlang.org/docs/language_guide#remix-integration

## macOS

This guides you through installing Flint in its current state on macOS

## Prerequisites
The following must be installed to build Flint on Macs:
* xcode - preferences/Locations/Command Line tools must not be empty (the default)
* homebrew - https://brew.sh, update brew if it isn't new with brew update
* brew install node - get node and npm if you don't have them
* brew install wget - get wget if you don't have it
* install swiftenv - here is a script to do this:
```
git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bash_profile
echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(swiftenv init -)"' >> ~/.bash_profile
```

