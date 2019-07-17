FROM swift:5.0.1-bionic

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]

RUN apt-get update
RUN rm -rf /usr/lib/python2.7/site-packages
RUN apt-get -y install --reinstall libpython2.7-minimal
RUN apt-get install -y python
RUN apt-get install -y software-properties-common curl git zip sudo wget gnupg ca-certificates apt-transport-https
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
RUN apt-get update
RUN apt-get install -y solc nodejs mono-devel

WORKDIR /tmp
RUN git clone -b "0.29.0" https://github.com/realm/SwiftLint.git swiftlint
WORKDIR /tmp/swiftlint
RUN swift build -c release --static-swift-stdlib
ENV PATH="/tmp/swiftlint/.build/x86_64-unknown-linux/release:${PATH}"

COPY . /flint
WORKDIR /flint
RUN npm install
RUN npm install -g truffle@4.1.14

WORKDIR /flint
RUN swift package update
RUN echo 'alias flintc="/flint/.build/release/flintc"' >> ~/.bashrc
