FROM swiftdocker/swift

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]
RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN apt-get update
RUN apt-get -y install solc

RUN apt-get -qq -y install clang

ENV SWIFTENV_ROOT /usr/local
ADD https://github.com/kylef/swiftenv/archive/1.2.1.tar.gz /tmp/swiftenv.tar.gz
RUN tar -xzf /tmp/swiftenv.tar.gz -C /usr/local/ --strip 1

ENV PATH /usr/local/shims:$PATH

COPY . /flint/

RUN cd /flint && make release
RUN echo 'alias flintc="/flint/.build/release/flintc"' >> ~/.bashrc
