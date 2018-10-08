FROM swift:4.2

LABEL maintainer "Franklin Schrans <f.schrans@me.com>"

SHELL ["/bin/bash", "-c"]
RUN apt-get update
RUN apt-get install -y software-properties-common curl git zip
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN apt-get update
RUN apt-get -y install solc

COPY . /flint/

RUN cd /flint && make release
RUN echo 'alias flintc="/flint/.build/release/flintc"' >> ~/.bashrc
