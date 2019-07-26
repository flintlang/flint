#!/bin/bash
apt-get update
apt-get install sudo
sudo apt-get install -y software-properties-common curl git zip sudo wget gnupg ca-certificates apt-transport-https sed python python3 libpython2.7
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
sudo add-apt-repository -y ppa:ethereum/ethereum
curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
sudo apt-get update
sudo apt-get install -y solc nodejs mono-complete clang
npm install
npm install -g truffle@4
eval "$(curl -sL https://swiftenv.fuller.li/install.sh)"
git clone https://github.com/realm/SwiftLint.git /tmp/swiftlint
(cd /tmp/swiftlint; swiftenv install; swift build -c release --static-swift-stdlib)
export PATH="/tmp/swiftlint/.build/x86_64-unknown-linux/release:$PATH"
swiftenv install 5.0.2
swiftenv install 4.2
echo 'export FLINTPATH="$PWD"' >> ~/.bash_profile
source ~/.bash_profile
make
