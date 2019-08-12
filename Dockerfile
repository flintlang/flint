FROM ubuntu:18.04

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]

RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip sudo wget gnupg ca-certificates apt-transport-https sed python python3
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
RUN apt-get update
RUN apt-get install -y solc nodejs mono-complete clang z3
WORKDIR /root
RUN git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
RUN echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bash_profile
RUN echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bash_profile
RUN echo 'eval "$(swiftenv init -)"' >> ~/.bash_profile
RUN eval "$(curl -sL https://swiftenv.fuller.li/install.sh)"
RUN cat ~/.bash_profile
RUN source ~/.bash_profile && swiftenv install 5.0.2 && swiftenv install 4.2 && swiftenv install 5.0
RUN git clone https://github.com/realm/SwiftLint.git /tmp/swiftlint
WORKDIR /tmp/swiftlint
RUN source ~/.bash_profile && swift build -c release --static-swift-stdlib
RUN echo 'export PATH="/tmp/swiftlint/.build/x86_64-unknown-linux/release:${PATH}"' >> ~/.bash_profile
COPY . /flint
WORKDIR /flint
RUN npm install
RUN npm install -g truffle@4
ENV FLINTPATH="/flint"
RUN source ~/.bash_profile && make
