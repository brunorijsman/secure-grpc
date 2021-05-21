if [ -z "${VIRTUAL_ENV}" ] ; then
    echo "Must run from Python virtual environment"
    exit 1
fi
SECURE_GRPC_PATH="${VIRTUAL_ENV}/.."

# For pass-though of --authentication and --signer options
more_options="$@"

# Remove the docker network from a previous run if it is still around
docker network rm secure-grpc-net >/dev/null 2>&1

# Create an isolated docker network between the server and the client
docker network create --subnet=172.30.0.0/16 secure-grpc-net >/dev/null

# Remove the server docker container from the previous run if it is still around
docker rm secure-grpc-server >/dev/null 2>&1

# Start the server docker container
docker run \
    --name secure-grpc-server \
    --network secure-grpc-net \
    --ip 172.30.0.2 \
    --hostname secure-grpc-server \
    --volume ${SECURE_GRPC_PATH}:/host \
    secure-grpc \
    bash -c "cd /host && python3 server.py --client-host secure-grpc-client \
             --server-host secure-grpc-server ${more_options}"
