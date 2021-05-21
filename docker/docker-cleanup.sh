#!/bin/bash

# Copyright 2021 Bruno Rijsman
# Apache License Version 2.0; see LICENSE for details

docker rm secure-grpc-server >/dev/null 2>&1
docker rm secure-grpc-client >/dev/null 2>&1
docker network rm secure-grpc-net >/dev/null 2>&1
