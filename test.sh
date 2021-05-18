#!/bin/bash

FALSE=0
TRUE=1

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BEEP=$(tput bel)

function client_to_server_call ()
{
    authentication=$1
    signer=$2

    if [[ ${signer} == "" ]]; then
        signer_option=""
    else
        signer_option="--signer $signer"
    fi

    ./server.py --authentication $authentication $signer_option >/dev/null 2>&1 &
    server_pid=$!
    sleep 0.2

    if ./client.py --authentication $authentication $signer_option >/dev/null 2>&1; then
        failure=$FALSE
    else
        failure=$TRUE
    fi

    kill ${server_pid} 
    wait ${server_pid} 2>/dev/null

    return $failure
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

    ./create-keys-and-certs.sh --authentication $authentication $signer_option >/dev/null 2>&1

    description="success_test_case: autentication=$authentication signer=$signer"

    if client_to_server_call $authentication $signer; then
        echo "${GREEN}Pass${NORMAL}: $description"
    else
        echo "${RED}Fail${NORMAL}: $description"
    fi
}

function success_test_cases ()
{
    success_test_case none
    success_test_case server self
    success_test_case server root
    success_test_case server intermediate
    success_test_case mutual self
    success_test_case mutual root
    success_test_case mutual intermediate
}

success_test_cases