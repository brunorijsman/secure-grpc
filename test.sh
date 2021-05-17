#!/bin/bash

../server.py --authentication mutual --signer root >server.out 2>&1 &
server_pid=$!

if ../client.py --authentication mutual --signer root >client.out 2>&1; then
    echo Success
else
    echo Failure
fi

kill ${server_pid}
