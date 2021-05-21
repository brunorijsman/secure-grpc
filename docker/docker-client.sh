#!/bin/bash

# Copyright 2021 Bruno Rijsman
# Apache License Version 2.0; see LICENSE for details

if [ -z "${VIRTUAL_ENV}" ] ; then
    echo "Must run from Python virtual environment"
    exit 1
fi
SECURE_GRPC_PATH="${VIRTUAL_ENV}/.."

# For pass-though of --authentication and --signer options
more_options="$@"

# Remove the client docker container from the previous run if it is still around
docker rm secure-grpc-client >/dev/null 2>&1

# Start the client docker container
docker run \
    --name secure-grpc-client \
    --network secure-grpc-net \
    --ip 172.30.0.3 \
    --hostname secure-grpc-client \
    --volume ${SECURE_GRPC_PATH}:/host \
    secure-grpc \
    bash -c "cd /host && python3 client.py --client-host secure-grpc-client \
             --server-host secure-grpc-server ${more_options}"
