#!/bin/bash

FALSE=0
TRUE=1

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)

VERBOSE=$FALSE
SKIP_EVANS=$FALSE
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
    echo "  in separate docker containers, each with a different DNS name."
    echo
    echo "  We use two different clients for testing: client.py in this repo and Evans"
    echo "  (https://github.com/ktr0731/evans)"
    echo
    echo "OPTIONS"
    echo
    echo "  --help, -h, -?"
    echo "      Print this help and exit"
    echo
    echo "  --skip-evans"
    echo "      Skip the Evans client test cases."
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
    local message="$1"

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
    local command=$1
    local failure_msg="$2"

    local status
    if [[ $VERBOSE == $TRUE ]]; then
        local output
        echo "Execute command:"
        echo "${BLUE}${command}${NORMAL}"
        output="$(eval $command)"
        status=$?
        echo "Command output:"
        echo "${BLUE}${output}${NORMAL}"
    else
        (eval $command) >/dev/null 2>&1
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

function start_process ()
{
    local command="$1"
    local pid_return_var="$2"

    local start_process_pid
    if [[ $VERBOSE == $TRUE ]]; then
        echo "Execute background command:"
        echo "${BLUE}${command} &${NORMAL}"
        echo "Background command start output:"
        echo ${BLUE}
        $command &
        start_process_pid=$!
        echo ${NORMAL}
    else
        $command >/dev/null 2>&1 &
        start_process_pid=$!
    fi
    eval $pid_return_var="'$start_process_pid'"
}

function create_keys_and_certs ()
{
    local location=$1
    local authentication=$2
    local signer=$3
    local wrong_key=$4

    local command="./create-keys-and-certs.sh"
    command="$command --authentication $authentication"
    if [[ ${signer} != "none" ]]; then
        command="$command --signer $signer"
    fi
    if [[ $location == local ]]; then
        command="$command --server-name localhost"
        command="$command --client-name localhost"
    else
        command="$command --server-name secure-grpc-server"
        command="$command --client-name secure-grpc-client"
    fi
    command="$command --wrong-key $wrong_key"

    run_command "$command" "Could not create private keys and certificates"
}

function start_server ()
{
    local location=$1
    local authentication=$2
    local signer=$3
    local server_pid_return_var=$4

    local options="--authentication $authentication"
    if [[ $authentication != "none" ]]; then
        if [[ $signer == "self" ]]; then
            options="$options --signer self"
        else
            options="$options --signer ca"
        fi
    fi
    if [[ $location == local ]]; then
        options="$options --server-name localhost --client-name localhost"
    else
        options="$options --server-name secure-grpc-server --client-name secure-grpc-client"
    fi

    local start_server_pid
    if [[ $location == local ]]; then
        start_process "./server.py $options" start_server_pid
    else
        start_process "docker/docker-server.sh $options" start_server_pid
        local server_container_id=""
        while [[ $server_container_id == "" ]]; do
            server_container_id=$(docker ps --filter name=secure-grpc-server --quiet)
        done
    fi
    sleep 0.2

    eval $server_pid_return_var="'$start_server_pid'"
}

function stop_server ()
{
    local location=$1
    local server_pid=$2

    kill ${server_pid} 2>/dev/null
    wait ${server_pid} 2>/dev/null
    if [[ $location == docker ]]; then
        local server_container_id=$(docker ps --filter name=secure-grpc-server --quiet)
        if [[ $server_container_id != "" ]]; then
            docker rm --force $server_container_id >/dev/null
        fi
    fi
}

function python_client_to_server_call ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4

    start_server $location $authentication $signer server_pid
    
    local command
    if [[ $location == local ]]; then
        command="./client.py"
    else
        command="docker/docker-client.sh"
    fi
    command="$command --authentication $authentication"
    if [[ $signer == "none" ]]; then
        :
    elif [[ $signer == "self" ]]; then
        command="$command --signer self"
    else
        command="$command --signer ca"
    fi
    if [[ $location == local ]]; then
        command="$command --server-name localhost --client-name localhost"
    else
        command="$command --server-name secure-grpc-server --client-name secure-grpc-client"
    fi

    local failure
    if run_command "$command" "return-error"; then
        failure=$FALSE
    else
        failure=$TRUE
    fi

    stop_server $location $server_pid

    return $failure
}

function evans_client_to_server_call ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4

    start_server $location $authentication $signer server_pid

    local command
    if [[ $location == local ]]; then
        command="evans --proto adder.proto cli call --host localhost"
    else
        command="docker/docker-evans.sh"
    fi
    if [[ $authentication != "none" ]]; then
        command="$command --tls"
        if [[ $signer == "self" ]]; then
            command="$command --cacert certs/server.crt"
        else
            command="$command --cacert certs/root.crt"
        fi
        if [[ $authentication == "mutual" ]]; then
            command="$command --cert certs/client.pem --certkey keys/client.key"
        fi
    fi
    command="$command adder.Adder.Add"
    command="$command <<< '{\"a\": \"1\", \"b\":\"2\"}'"
    
    local failure
    if run_command "$command" "return-error"; then
        failure=$FALSE
    else
        failure=$TRUE
    fi

    stop_server $location $server_pid

    return $failure
}

function client_to_server_call ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4

    if [[ $client == python ]]; then
        python_client_to_server_call $location $client $authentication $signer
    else
        evans_client_to_server_call $location $client $authentication $signer
    fi
}

function correct_key_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4

    create_keys_and_certs $location $authentication $signer none

    description="correct_key_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer"

    if client_to_server_call $location $client $authentication $signer; then
        echo "${GREEN}Pass${NORMAL}: $description"
    else
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    fi
}

function correct_key_test_cases ()
{
    local location=$1
    local client=$2

    correct_key_test_case $location $client none none
    correct_key_test_case $location $client server self
    correct_key_test_case $location $client server root
    correct_key_test_case $location $client server intermediate
    correct_key_test_case $location $client mutual self
    correct_key_test_case $location $client mutual root
    correct_key_test_case $location $client mutual intermediate
}

function wrong_key_test_case ()
{
    local location=$1
    local authentication=$2
    local signer=$3
    local wrong_key=$4

    create_keys_and_certs $location $authentication $signer $wrong_key

    description="wrong_key_test_case: location=$location authentication=$authentication"
    description="$description signer=$signer wrong_key=$wrong_key"

    # Since the key is wrong, we expect the call to fail and the test case passes if the call fails
    if client_to_server_call $location python $authentication $signer; then
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    else
        echo "${GREEN}Pass${NORMAL}: $description"
    fi
}

function wrong_key_test_cases ()
{
    local location=$1

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
    correct_key_test_cases local python
    if [[ $SKIP_EVANS == $FALSE ]]; then
        correct_key_test_cases local evans
    fi
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases local
    fi
}

function docker_test_cases ()
{
    correct_key_test_cases docker python
    if [[ $SKIP_EVANS == $FALSE ]]; then
        correct_key_test_cases docker evans
    fi
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases docker local
        wrong_key_test_cases docker evans
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
