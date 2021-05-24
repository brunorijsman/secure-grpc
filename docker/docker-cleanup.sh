#!/bin/bash

if [[ $(docker ps --filter name=secure-grpc-server --quiet) != "" ]]; then
    docker rm secure-grpc-server >/dev/null 2>&1
fi
if [[ $(docker ps --filter name=secure-grpc-client --quiet) != "" ]]; then
    docker rm secure-grpc-client >/dev/null 2>&1
fi
if [[ $(docker network ls --filter name=secure-grpc-net --quiet) != "" ]]; then
    docker network rm secure-grpc-net >/dev/null 2>&1
fi
