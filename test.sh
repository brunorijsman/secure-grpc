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

DO_OVERRIDE_NAME=$TRUE
DONT_OVERRIDE_NAME=$FALSE

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
    echo "  The server can identify itself using the DNS name of the host on which it runs, or"
    echo "  it can use the TLS server name indication (SNI) to identify itself using a service"
    echo "  name."
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
            --skip-evans)
                SKIP_EVANS=$TRUE
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
    local override_name=$5

    local command="./create-keys-and-certs.sh"
    command="$command --authentication $authentication"
    if [[ ${signer} != "none" ]]; then
        command="$command --signer $signer"
    fi
    if [[ $location == local ]]; then
        if [[ $override_name == $TRUE ]]; then
            command="$command --server-name adder-server-service"
        else
            command="$command --server-name localhost"
        fi
        command="$command --client-name localhost"
    else
        if [[ $override_name == $TRUE ]]; then
            command="$command --server-name adder-server-service"
        else
            command="$command --server-name adder-server-host"
        fi
        command="$command --client-name adder-client-host"
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
        options="$options --server-host localhost --client-host localhost"
    else
        options="$options --server-host adder-server-host --client-host adder-client-host"
    fi

    local start_server_pid
    if [[ $location == local ]]; then
        start_process "./server.py $options" start_server_pid
    else
        start_process "docker/docker-server.sh $options" start_server_pid
        local server_container_id=""
        while [[ $server_container_id == "" ]]; do
            server_container_id=$(docker ps --filter name=adder-server-host --quiet)
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
        local server_container_id=$(docker ps --filter name=adder-server-host --quiet)
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
    local override_name=$5

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
        command="$command --server-host localhost --client-host localhost"
    else
        command="$command --server-host adder-server-host --client-host adder-client-host"
    fi
    if [[ $override_name == $TRUE ]]; then
        command="$command --server-name adder-server-service"
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
    local override_name=$5

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
        if [[ $override_name == $TRUE ]]; then
            command="$command --servername adder-server-service"
        fi
    fi
    if [[ $location == local ]]; then
        command="$command adder.Adder.Add"
        command="$command <<< '{\"a\": \"1\", \"b\":\"2\"}'"
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

function client_to_server_call ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local override_name=$5

    if [[ $client == python ]]; then
        python_client_to_server_call $location $client $authentication $signer $override_name
    else
        evans_client_to_server_call $location $client $authentication $signer $override_name
    fi
}

function correct_key_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local override_name=$5

    create_keys_and_certs $location $authentication $signer none $override_name

    description="correct_key_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer"
    description="$description override_name=$override_name"

    if client_to_server_call $location $client $authentication $signer $override_name; then
        echo "${GREEN}Pass${NORMAL}: $description"
    else
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    fi
}

function correct_key_test_cases_group ()
{
    local location=$1
    local client=$2
    local override_name=$3

    correct_key_test_case $location $client none none $override_name
    correct_key_test_case $location $client server self $override_name
    correct_key_test_case $location $client server root $override_name
    correct_key_test_case $location $client server intermediate $override_name
    correct_key_test_case $location $client mutual self $override_name
    correct_key_test_case $location $client mutual root $override_name
    correct_key_test_case $location $client mutual intermediate $override_name
}

function correct_key_test_cases ()
{
    local location=$1

    correct_key_test_cases_group $location python $DONT_OVERRIDE_NAME
    correct_key_test_cases_group $location python $DO_OVERRIDE_NAME
    if [[ $SKIP_EVANS == $FALSE ]]; then
        correct_key_test_cases_group $location evans $DONT_OVERRIDE_NAME
        correct_key_test_cases_group $location evans $DO_OVERRIDE_NAME
    fi
}

function wrong_key_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local wrong_key=$5

    create_keys_and_certs $location $authentication $signer $wrong_key $DONT_OVERRIDE_NAME

    description="wrong_key_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer wrong_key=$wrong_key"

    # Since the key is wrong, we expect the call to fail and the test case passes if the call fails
    if client_to_server_call $location $client $authentication $signer $DONT_OVERRIDE_NAME; then
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    else
        echo "${GREEN}Pass${NORMAL}: $description"
    fi
}

function wrong_key_test_cases_group ()
{
    local location=$1
    local client=$2

    wrong_key_test_case $location $client server self server
    wrong_key_test_case $location $client server root server
    wrong_key_test_case $location $client server root root
    wrong_key_test_case $location $client server intermediate server
    wrong_key_test_case $location $client server intermediate root
    wrong_key_test_case $location $client server intermediate intermediate
    wrong_key_test_case $location $client mutual self server
    wrong_key_test_case $location $client mutual self client
    wrong_key_test_case $location $client mutual root server
    wrong_key_test_case $location $client mutual root client
    wrong_key_test_case $location $client mutual root root
    wrong_key_test_case $location $client mutual intermediate server
    wrong_key_test_case $location $client mutual intermediate client
    wrong_key_test_case $location $client mutual intermediate root
    wrong_key_test_case $location $client mutual intermediate intermediate
}

function wrong_key_test_cases ()
{
    local location=$1

    wrong_key_test_cases_group $location python
    if [[ $SKIP_EVANS == $FALSE ]]; then
        wrong_key_test_cases_group $location evans
    fi
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
