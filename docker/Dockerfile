# Copyright 2021 Bruno Rijsman
# Apache License Version 2.0; see LICENSE for details

FROM ubuntu:20.04
RUN apt-get update -y
RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN apt-get install -y net-tools
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
VOLUME /host
