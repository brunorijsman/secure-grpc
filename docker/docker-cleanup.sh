#!/bin/bash

docker rm secure-grpc-server >/dev/null 2>&1
docker rm secure-grpc-client >/dev/null 2>&1
docker network rm secure-grpc-net >/dev/null 2>&1
