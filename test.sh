#!/bin/bash

# TODO: Add verbose option
# TODO: Test error reporting (make something fail on purpose)

FALSE=0
TRUE=1

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)

VERBOSE=$FALSE
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
    echo "OPTIONS"
    echo
    echo "  --help, -h, -?"
    echo "      Print this help and exit"
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
    authentication=$1
    signer=$2
    wrong_key=$3

    if [[ ${signer} == "none" ]]; then
        signer_option=""
    else
        signer_option="--signer $signer"
    fi

    run_command "./create-keys-and-certs.sh --authentication $authentication $signer_option --wrong-key $wrong_key" \
                "Could not create private keys and certificates"
}

function client_to_server_call ()
{
    authentication=$1
    signer=$2

    if [[ ${signer} == "none" ]]; then
        signer_option=""
    else
        signer_option="--signer $signer"
    fi

    run_command "./server.py --authentication $authentication $signer_option" \
                "Could not start server" \
                $TRUE
    server_pid=$!
    sleep 0.2

    if run_command "./client.py --authentication $authentication $signer_option" "return-error"; then
        failure=$FALSE
    else
        failure=$TRUE
    fi

    kill ${server_pid} 2>/dev/null
    wait ${server_pid} 2>/dev/null

    return $failure
}

function correct_key_test_case ()
{
    authentication=$1
    signer=$2

    create_keys_and_certs $authentication $signer none

    description="correct_key_test_case: authentication=$authentication signer=$signer"

    if client_to_server_call $authentication $signer; then
        echo "${GREEN}Pass${NORMAL}: $description"
    else
        echo "${RED}Fail${NORMAL}: $description"
        ((TEST_CASES_FAILED = TEST_CASES_FAILED + 1))
    fi
}

function correct_key_test_cases ()
{
    correct_key_test_case none none
    correct_key_test_case server self
    correct_key_test_case server root
    correct_key_test_case server intermediate
    correct_key_test_case mutual self
    correct_key_test_case mutual root
    correct_key_test_case mutual intermediate
}

function wrong_key_test_case ()
{
    authentication=$1
    signer=$2
    wrong_key=$3

    create_keys_and_certs $authentication $signer $wrong_key

    description="wrong_key_test_case: authentication=$authentication signer=$signer"
    description="$description wrong_key=$wrong_key"

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
    wrong_key_test_case server self server
    wrong_key_test_case server root server
    wrong_key_test_case server root root
    wrong_key_test_case server intermediate server
    wrong_key_test_case server intermediate root
    wrong_key_test_case server intermediate intermediate
    wrong_key_test_case mutual self server
    wrong_key_test_case mutual self client
    wrong_key_test_case mutual root server
    wrong_key_test_case mutual root client
    wrong_key_test_case mutual root root
    wrong_key_test_case mutual intermediate server
    wrong_key_test_case mutual intermediate client
    wrong_key_test_case mutual intermediate root
    wrong_key_test_case mutual intermediate intermediate
}

parse_command_line_options $@

correct_key_test_cases
wrong_key_test_cases

if [[ $TEST_CASES_FAILED == 0 ]]; then
    echo "${GREEN}All test cases passed${NORMAL}"
else
    echo "${RED}$TEST_CASES_FAILED test cases failed${NORMAL}"
fi
