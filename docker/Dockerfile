FROM ubuntu:20.04
RUN apt-get update -y
RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN apt-get install -y net-tools
RUN apt-get install -y wget
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
RUN wget https://github.com/ktr0731/evans/releases/download/0.9.3/evans_linux_amd64.tar.gz
RUN tar xvf evans_linux_amd64.tar.gz
VOLUME /host
