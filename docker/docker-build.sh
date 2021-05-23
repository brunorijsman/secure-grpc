#!/bin/bash

# Build a container for testing secure-grpc on something else than just localhost
#
# Note that this container does not actually include the secure-grpc code; instead it is intended
# to be run with a volume that allows it to access the secure-grpc code on the host development
# computer.

if [ -z "${VIRTUAL_ENV}" ] ; then
    echo "Must run from Python virtual environment"
    exit 1
fi
SECURE_GRPC_PATH="${VIRTUAL_ENV}/.."

cd ${SECURE_GRPC_PATH}/docker

cp ../requirements.txt .

docker build . --tag secure-grpc