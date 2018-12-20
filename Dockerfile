FROM swift:4.2

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]
RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip sudo
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
RUN apt-get update
RUN apt-get -y install solc nodejs
RUN npm install
RUN npm install -g truffle
RUN git clone -b "0.29.0" https://github.com/realm/SwiftLint.git /tmp/swiftlint
RUN (cd /tmp/swiftlint; swift build -c release --static-swift-stdlib)
ENV PATH="/tmp/swiftlint/.build/x86_64-unknown-linux/release:${PATH}"

COPY . /flint/

RUN cd /flint && make release
RUN echo 'alias flintc="/flint/.build/release/flintc"' >> ~/.bashrc
