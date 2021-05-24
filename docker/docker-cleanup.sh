#!/bin/bash

if [[ $(docker ps --filter name=adder-server-host --quiet) != "" ]]; then
    docker rm --force adder-server-host >/dev/null
fi
if [[ $(docker ps --filter name=adder-client-host --quiet) != "" ]]; then
    docker rm --force adder-client-host >/dev/null
fi
if [[ $(docker network ls --filter name=secure-grpc-net --quiet) != "" ]]; then
    docker network rm secure-grpc-net >/dev/null
fi
