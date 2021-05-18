#!/bin/bash

# FALSE=0
# TRUE=1

# NORMAL=$(tput sgr0)
# RED=$(tput setaf 1)
# BLUE=$(tput setaf 4)
# BEEP=$(tput bel)

function client_to_server_call ()
{
    authentication=$1
    signer=$2

    if [[ ${signer} == "" ]]; then
        signer_option=""
    else
        signer_option="--signer $signer"
    fi

    # ./server.py --authentication $authentication $signer_option >server.out 2>&1 &
    ./server.py --authentication $authentication $signer_option &
    server_pid=$!
    sleep 0.2

    # if ./client.py --authentication $authentication $signer_option >client.out 2>&1; then
    if ./client.py --authentication $authentication $signer_option; then
        echo Success
    else
        echo Failure
    fi

    kill ${server_pid}
}

function success_test_case ()
{
    authentication=$1
    signer=$2

    if [[ ${signer} == "" ]]; then
        signer_option=""
    else
        signer_option="--signer $signer"
    fi

    ./create-keys-and-certs.sh --authentication $authentication $signer_option

    client_to_server_call $authentication $signer
}

# success_test_case none
success_test_case server self
