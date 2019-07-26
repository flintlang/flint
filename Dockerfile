FROM ubuntu:18.04
# Currently not working

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]

RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip sudo wget gnupg ca-certificates apt-transport-https sed python python3
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
RUN apt-get update
RUN apt-get install -y solc nodejs mono-complete clang

WORKDIR /root
RUN git clone https://github.com/kylef/swiftenv.git .swiftenv
RUN echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> .bashrc
RUN echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> .bashrc
RUN echo 'eval "$(swiftenv init -)"' >> .bashrc
RUN eval "$(curl -sL https://swiftenv.fuller.li/install.sh)"
RUN swiftenv install 5.0.2
RUN swiftenv install 4.2
RUN ls .swiftenv
RUN git clone https://github.com/realm/SwiftLint.git swiftlint
WORKDIR /tmp/swiftlint
RUN swift build -c release --static-swift-stdlib
ENV PATH="/tmp/swiftlint/.build/x86_64-unknown-linux/release:${PATH}"
COPY . /flint
WORKDIR /flint
RUN npm install
RUN npm install -g truffle@4
RUN swift package update
ENV FLINTPATH="/flint"