FROM ubuntu:18.04

RUN apt-get update \
    && apt-get install -qy zsh ksh expect openssl shellcheck

RUN mkdir /opt/encpass

VOLUME /opt/encpass
