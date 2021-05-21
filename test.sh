#!/bin/bash

FALSE=0
TRUE=1

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)

VERBOSE=$FALSE
SKIP_DOCKER=$FALSE
SKIP_NEGATIVE=$FALSE
TEST_CASES_FAILED=0

function help ()
{
    echo
    echo "SYNOPSIS"
    echo
    echo "    test.sh [OPTION]..."
    echo
    echo "DESCRIPTION"
    echo
    echo "  Test authentication between the gRPC client and the gRPC server."
    echo "  "
    echo "  The following authentication methods are tested: no authentication, server"
    echo "  authentication (the client authenticates the server, but not vice versa), and mutual"
    echo "  authentication (the client and the server mutually authenticate each other)."
    echo
    echo "  The following certificate signing methods are tested: self-signed certificates,"
    echo "  certificates signed by a root CA, and certificates signed by an intermediate CA."
    echo
    echo "  There are both positive and negative test cases. The positive test cases verify that"
    echo "  the gRPC client can successfully call the gRPC server when all keys and cerficicates"
    echo "  correct. The negatite test cases verity that the gRPC client cannot call the gRPC"
    echo "  when some private key is incorrect, i.e. does not match the public key in the"
    echo "  certificate."
    echo
    echo "  The tests are run in two environments: local and docker. The local test runs the server"
    echo "  and client as local processes on localhost. The docker test runs the server and client"
    echo "  in separate docker containers, each with a different hostname."
    echo
    echo "OPTIONS"
    echo
    echo "  --help, -h, -?"
    echo "      Print this help and exit"
    echo
    echo "  --skip-docker"
    echo "      Skip the docker test cases."
    echo
    echo "  --skip-negative"
    echo "      Skip the negative test cases."
    echo
    echo "  --verbose, -v"
    echo "      Verbose output; show all executed commands and their output."
    exit 0
}

function fatal_error ()
{
    message="$1"
    echo "${RED}Error:${NORMAL} ${message}" >&2
    exit 1
}

function parse_command_line_options ()
{
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help|-h|-\?)
                help
                ;;
            --skip-docker)
                SKIP_DOCKER=$TRUE
                ;;
            --skip-negative)
                SKIP_NEGATIVE=$TRUE
                ;;
            --verbose|-v)
                VERBOSE=$TRUE
                ;;
            *)
                fatal_error "Unknown parameter passed: $1"
                ;;
        esac
        shift
    done
}

function run_command ()
{
    command="$1"
    failure_msg="$2"
    run_in_background="$3"

    if [[ $run_in_background == $TRUE ]]; then
        if [[ $VERBOSE == $TRUE ]]; then
            echo "Execute background command:"
            echo "${BLUE}${command} &${NORMAL}"
            echo "Background command start output:"
            echo ${BLUE}
            $command &
            echo ${NORMAL}
        else
            $command >/dev/null 2>&1 &
        fi
        return 0
    fi

    if [[ $VERBOSE == $TRUE ]]; then
        echo "Execute command:"
        echo "${BLUE}${command}${NORMAL}"
        output=$($command)
        status=$?
        echo "Command output:"
        echo "${BLUE}${output}${NORMAL}"
    else
        $command >/dev/null 2>&1
        status=$?
    fi

    if [[ $status -ne 0 ]] ; then
        if [[ "$failure_msg" == "return-error" ]]; then
            return $status
        fi
        echo "${RED}Error:${NORMAL} $failure_msg"
        exit 1
    fi
    return 0
}

function create_keys_and_certs ()
{
    location=$1
    authentication=$2
    signer=$3
    wrong_key=$4

    command="./create-keys-and-certs.sh"
    command="$command --authentication $authentication"
    if [[ ${signer} != "none" ]]; then
        command="$command --signer $signer"
    fi
    if [[ $location == local ]]; then
        command="$command --server-host localhost"
        command="$command --client-host localhost"
    else
        command="$command --server-host secure-grpc-server"
        command="$command --client-host secure-grpc-client"
    fi
    command="$command --wrong-key $wrong_key"

    run_command "$command" "Could not create private keys and certificates"
}

function client_to_server_call ()
{
    authentication=$1
    signer=$2

    options="--authentication $authentication"
    if [[ $signer == "none" ]]; then
        option="$options"
    elif [[ $signer == "self" ]]; then
        options="$options --signer self"
    else
        options="$options --signer ca"
    fi
    if [[ $location == local ]]; then
        options="$options --server-host localhost --client-host localhost"
    else
        options="$options --server-host secure-grpc-server --client-host secure-grpc-client"
    fi

    if [[ $location == local ]]; then
        run_command "./server.py $options" "Could not start local server" $TRUE
        server_pid=$!
    else
        run_command "docker/docker-server.sh $options" "Could not start docker server" $TRUE
        server_pid=$!
        server_container_id=""
        while [[ $server_container_id == "" ]]; do
            server_container_id=$(docker ps --filter name=secure-grpc-server --quiet)
        done
    fi
    sleep 0.2

    if [[ $location == local ]]; then
        command="./client.py"
    else
        command="docker/docker-client.sh"
    fi

    if run_command "$command $options" "return-error"; then
        failure=$FALSE
    else
        failure=$TRUE
    fi

    kill ${server_pid} 2>/dev/null
    wait ${server_pid} 2>/dev/null
    if [[ $location == docker ]]; then
        docker rm --force $server_container_id >/dev/null
    fi

    return $failure
}

function correct_key_test_case ()
{
    location=$1
    authentication=$2
    signer=$3

    create_keys_and_certs $location $authentication $signer none

    description="correct_key_test_case: location=$location authentication=$authentication"
    description="$description signer=$signer"

    if client_to_server_call $authentication $signer; then
        echo "${GREEN}Pass${NORMAL}: $description"
    else
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    fi
}

function correct_key_test_cases ()
{
    location=$1

    correct_key_test_case $location none none
    correct_key_test_case $location server self
    correct_key_test_case $location server root
    correct_key_test_case $location server intermediate
    correct_key_test_case $location mutual self
    correct_key_test_case $location mutual root
    correct_key_test_case $location mutual intermediate
}

function wrong_key_test_case ()
{
    location=$1
    authentication=$2
    signer=$3
    wrong_key=$4

    create_keys_and_certs $location $authentication $signer $wrong_key

    description="wrong_key_test_case: location=$location authentication=$authentication"
    description="$description signer=$signer wrong_key=$wrong_key"

    # Since the key is wrong, we expect the call to fail and the test case passes if the call fails
    if client_to_server_call $authentication $signer; then
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    else
        echo "${GREEN}Pass${NORMAL}: $description"
    fi
}

function wrong_key_test_cases ()
{
    location=$1

    wrong_key_test_case $location server self server
    wrong_key_test_case $location server root server
    wrong_key_test_case $location server root root
    wrong_key_test_case $location server intermediate server
    wrong_key_test_case $location server intermediate root
    wrong_key_test_case $location server intermediate intermediate
    wrong_key_test_case $location mutual self server
    wrong_key_test_case $location mutual self client
    wrong_key_test_case $location mutual root server
    wrong_key_test_case $location mutual root client
    wrong_key_test_case $location mutual root root
    wrong_key_test_case $location mutual intermediate server
    wrong_key_test_case $location mutual intermediate client
    wrong_key_test_case $location mutual intermediate root
    wrong_key_test_case $location mutual intermediate intermediate
}

function local_test_cases ()
{
    correct_key_test_cases local
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases local
    fi
}

function docker_test_cases ()
{
    correct_key_test_cases docker
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases docker
    fi
}

parse_command_line_options $@

local_test_cases

if [[ $SKIP_DOCKER == $FALSE ]]; then
    echo "Building container..."
    run_command "docker/docker-build.sh" "Could not build container"
    run_command "docker/docker-cleanup.sh" "Could not clean containers from previous run"
    docker_test_cases
fi

if [[ $TEST_CASES_FAILED == 0 ]]; then
    echo "${GREEN}All test cases passed${NORMAL}"
else
    echo "${RED}$TEST_CASES_FAILED test cases failed${NORMAL}"
fi
