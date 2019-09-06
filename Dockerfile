FROM ubuntu:18.04
LABEL maintainer "Franklin Schrans <f.schrans@me.com>"
SHELL ["/bin/bash", "-c"]
RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip sudo wget gnupg ca-certificates apt-transport-https sed python python3 libpython2.7
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
RUN apt-get update
RUN apt-get install -y solc nodejs mono-complete clang z3
WORKDIR /root
RUN eval "$(curl -sL https://swiftenv.fuller.li/install.sh)"
RUN echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> /root/.bash_profile
RUN echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> /root/.bash_profile
RUN echo 'eval "$(swiftenv init -)"' >> /root/.bash_profile
RUN source /root/.bash_profile && swiftenv install 5.0.2 && swiftenv install 4.2 && swiftenv install 5.0
RUN git clone https://github.com/realm/SwiftLint.git /root/swiftlint
WORKDIR /root/swiftlint
RUN source ~/.bash_profile && swift build -c release --static-swift-stdlib
RUN echo 'export PATH="/root/swiftlint/.build/x86_64-unknown-linux/release:$PATH"' >> /root/.bash_profile
COPY . /root/.flint
WORKDIR /root/.flint
RUN npm install
RUN npm install -g truffle@4
RUN echo 'export PATH="/root/.flint/.build/release:$PATH"' >> /root/.bash_profile
RUN echo "source /root/.bash_profile" >> /root/.bashrc
RUN source ~/.bash_profile && swift package update
RUN source ~/.bash_profile && make release

