This guides you through installing Flint in its current state on Linux

**Contents**
1. Prerequisites
2. Installation
3. Docker

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
git clone --recurse-submodules https://github.com/flintlang/flint.git
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
git clone --recurse-submodules https://github.com/flintlang/flint.git
cd flint
sudo docker build .
sudo docker run -i -t .
### ---------------------------------------------- ###
# Docker will build, this process may take some time #
### ---------------------------------------------- ###
# root@...:/flint #
make; make  # Right now the first make will not link z3 correctly
```
