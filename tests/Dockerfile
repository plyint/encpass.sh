FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -qy zsh ksh expect openssl

RUN mkdir /opt/encpass

VOLUME /opt/encpass

WORKDIR /opt/encpass/tests
ENV HOME /opt/encpass/tests

ENTRYPOINT ["./suite.sh"]
