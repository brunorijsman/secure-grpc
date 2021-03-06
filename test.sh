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
TEST_CASES_PASSED=0
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
    echo "  the gRPC client can successfully call the gRPC server when all keys and certificates"
    echo "  correct. The negative test cases verity that the gRPC client cannot call the gRPC"
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
        echo "${BLUE}${command} 2>&1 &${NORMAL}"
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
    local server_naming=$5
    local client_naming=$6

    local command="./create-keys-and-certs.sh"
    command="$command --authentication $authentication"
    if [[ ${signer} != "none" ]]; then
        command="$command --signer $signer"
    fi
    if [[ $location == "local" ]]; then
        if [[ $server_naming == "service" ]]; then
            command="$command --server-name adder-server-service"
        else
            command="$command --server-name localhost"
        fi
        if [[ $client_naming == "service" ]]; then
            command="$command --client-name adder-client-service"
        else
            command="$command --client-name localhost"
        fi
    else
        if [[ $server_naming == "service" ]]; then
            command="$command --server-name adder-server-service"
        else
            command="$command --server-name adder-server-host"
        fi
        if [[ $client_naming == "service" ]]; then
            command="$command --client-name adder-client-service"
        else
            command="$command --client-name adder-client-host"
        fi
    fi
    command="$command --wrong-key $wrong_key"

    run_command "$command" "Could not create private keys and certificates"
}

function start_server ()
{
    local location=$1
    local authentication=$2
    local signer=$3
    local check_client_naming=$4
    local server_pid_return_var=$5

    local options="--authentication $authentication"
    if [[ $authentication != "none" ]]; then
        if [[ $signer == "self" ]]; then
            options="$options --signer self"
        else
            options="$options --signer ca"
        fi
    fi
    if [[ $location == "local" ]]; then
        options="$options --server-host localhost"
    else
        options="$options --server-host adder-server-host"
    fi
    if [[ $check_client_naming == "dont_check" ]]; then
        :
    elif [[ $check_client_naming == "host" ]]; then
        if [[ $location == "local" ]]; then
            options="$options --client-name localhost"
        else
            options="$options --client-name adder-client-host"
        fi
    elif [[ $check_client_naming == "service" ]]; then
        options="$options --client-name adder-client-service"
    elif [[ $check_client_naming == "wrong" ]]; then
        options="$options --client-name wrong-client-name"
    fi

    local start_server_pid
    if [[ $location == "local" ]]; then
        start_process "./server.py $options" start_server_pid
    else
        start_process "docker/docker-server.sh $options" start_server_pid
        local server_container_id=""
        while [[ $server_container_id == "" ]]; do
            server_container_id=$(docker ps --filter name=adder-server-host --quiet)
        done
        sleep 0.4
    fi
    sleep 0.4

    eval $server_pid_return_var="'$start_server_pid'"
}

function stop_server ()
{
    local location=$1
    local server_pid=$2

    kill ${server_pid} 2>/dev/null
    wait ${server_pid} 2>/dev/null
    if [[ $location == "docker" ]]; then
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
    local server_naming=$5
    local check_client_naming=$6

    start_server $location $authentication $signer $check_client_naming server_pid
    
    local command
    if [[ $location == "local" ]]; then
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
    if [[ $location == "local" ]]; then
        command="$command --server-host localhost"
    else
        command="$command --server-host adder-server-host"
    fi
    if [[ $server_naming == "service" ]]; then
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
    local server_naming=$5
    local check_client_naming=$6

    start_server $location $authentication $signer $check_client_naming server_pid

    local command
    if [[ $location == "local" ]]; then
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
        if [[ $server_naming == "service" ]]; then
            command="$command --servername adder-server-service"
        fi
    fi
    if [[ $location == "local" ]]; then
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
    local server_naming=$5
    local check_client_naming=$6

    if [[ $client == "python" ]]; then
        python_client_to_server_call $location $client $authentication $signer $server_naming \
            $check_client_naming
    else
        evans_client_to_server_call $location $client $authentication $signer $server_naming \
            $check_client_naming
    fi
}

function correct_key_test_case_check_client ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local server_naming=$5
    local client_naming=$6
    local check_client_naming=$7

    create_keys_and_certs $location $authentication $signer none $server_naming $client_naming

    description="correct_key_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer"
    description="$description server_naming=$server_naming"
    description="$description client_naming=$client_naming"
    description="$description check_client_naming=$check_client_naming"

    if client_to_server_call $location $client $authentication $signer $server_naming \
        $check_client_naming; then
        echo "${GREEN}Pass${NORMAL}: $description"
        ((TEST_CASES_PASSED = TEST_CASES_PASSED + 1))
    else
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    fi
}

function correct_key_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local server_naming=$5
    local client_naming=$5

    correct_key_test_case_check_client $location $client $authentication $signer \
        $server_naming $client_naming dont_check

    if [[ $authentication == "mutual" ]]; then
        correct_key_test_case_check_client $location $client $authentication $signer \
            $server_naming $client_naming $client_naming
    fi
}


function correct_key_test_cases_group ()
{
    local location=$1
    local client=$2
    local server_naming=$3
    local client_naming=$3

    correct_key_test_case $location $client none none $server_naming $client_naming
    correct_key_test_case $location $client server self $server_naming $client_naming
    correct_key_test_case $location $client server root $server_naming $client_naming
    correct_key_test_case $location $client server intermediate $server_naming $client_naming
    correct_key_test_case $location $client mutual self $server_naming $client_naming
    correct_key_test_case $location $client mutual root $server_naming $client_naming
    correct_key_test_case $location $client mutual intermediate $server_naming $client_naming
}

function correct_key_test_cases ()
{
    local location=$1

    for server_naming in host service; do
        for client_naming in host service; do
            correct_key_test_cases_group $location python $server_naming $client_naming
            if [[ $SKIP_EVANS == $FALSE ]]; then
                correct_key_test_cases_group $location evans $server_naming $client_naming
            fi
        done
    done
}

function wrong_key_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4
    local wrong_key=$5

    create_keys_and_certs $location $authentication $signer $wrong_key host host

    description="wrong_key_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer wrong_key=$wrong_key"

    # Since the key is wrong, we expect the call to fail and the test case passes if the call fails
    if client_to_server_call $location $client $authentication $signer host dont_check; then
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    else
        echo "${GREEN}Pass${NORMAL}: $description"
        ((TEST_CASES_PASSED = TEST_CASES_PASSED + 1))
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

function wrong_client_test_case ()
{
    local location=$1
    local client=$2
    local authentication=$3
    local signer=$4

    create_keys_and_certs $location $authentication $signer none host service

    description="wrong_client_test_case: location=$location client=$client"
    description="$description authentication=$authentication signer=$signer"

    # Authenticate the client using the wrong client name. This should fail.
    if client_to_server_call $location $client $authentication $signer host wrong; then
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    else
        echo "${GREEN}Pass${NORMAL}: $description"
        ((TEST_CASES_PASSED = TEST_CASES_PASSED + 1))
    fi
}

function wrong_client_test_cases_group ()
{
    local location=$1
    local client=$2

    wrong_client_test_case $location $client mutual self
    wrong_client_test_case $location $client mutual root
    wrong_client_test_case $location $client mutual intermediate
}

function wrong_client_test_cases ()
{
    local location=$1

    wrong_client_test_cases_group $location python
    if [[ $SKIP_EVANS == $FALSE ]]; then
        wrong_client_test_cases_group $location evans
    fi
}

function local_test_cases ()
{
    correct_key_test_cases local
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases local
        wrong_client_test_cases local
    fi
}

function docker_test_cases ()
{
    correct_key_test_cases docker
    if [[ $SKIP_NEGATIVE == $FALSE ]]; then
        wrong_key_test_cases docker
        wrong_client_test_cases docker
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
    echo "${GREEN}All $TEST_CASES_PASSED test cases passed${NORMAL}"
else
    msg="${RED}$TEST_CASES_FAILED test cases failed${NORMAL}"
    msg="$msg and ${GREEN}$TEST_CASES_PASSED test cases passed${NORMAL}"
    echo $msg
fi
