#!/bin/bash

FALSE=0
TRUE=1

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
BEEP=$(tput bel)

AUTHENTICATION="none"
CLEAN=${FALSE}
CLIENT_HOST="localhost"
SERVER_HOST="localhost"
SERVER_PORT=50051
SIGNER="self"

help ()
{
    echo
    echo "SYNOPSIS"
    echo
    echo "    create-keys-and-certs.sh [OPTION]..."
    echo
    echo "OPTIONS"
    echo
    echo "  --help, -h, -?"
    echo "      Print this help and exit"
    echo
    echo "  --authentication {none, server, mutual}, -A {none, server, mutual}"
    echo "      none: no authentication."
    echo "      server: the client authenticates the server."
    echo "      mutual: the client and the server mutually authenticate each other."
    echo "      (Default: none)"
    echo
    echo "  --client-host, -c"
    echo "      The client hostname. Default: localhost."
    echo
    echo "  --server-host, -s"
    echo "      The server hostname. Default: localhost."
    echo
    echo "  --server-port, -p"
    echo "      The server port number. Default: 50051."
    echo
    echo "  --signer, -i"
    echo "      Use Certificate Authority (CA) signed certificates (default: use self-signed"
    echo "      certificates)"
    echo
    echo "  -x, --clean"
    echo "      Remove all private key and certificate files."
    echo
    exit 0
}

fatal_error ()
{
    message="$1"
    echo "${RED}Error:${NORMAL} ${message}" >&2
    exit 1
}

parse_command_line_options ()
{
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help|-h|-\?)
                help
                ;;
            --authentication|-A)
                AUTHENTICATION="$2"
                shift
                if [[ "${AUTHENTICATION}" != "none" ]] && \
                   [[ "${AUTHENTICATION}" != "server" ]] && \
                   [[ "${AUTHENTICATION}" != "mutual" ]]; then
                      fatal_error "Unknown authentication \"$AUTHENTICATION\". Use none, server, or mutual"
                fi
                ;;
            --clean|-x)
                CLEAN=${TRUE}
                ;;
            --client-host|-c)
                CLIENT_HOST="$2"
                shift
                ;;
            --server-host|-s)
                SERVER_HOST="$2"
                shift
                ;;
            --server-port|-p)
                SERVER_PORT="$2"
                shift
                ;;
            --signer|-i)
                SIGNER="$2"
                shift
                if [[ "${SIGNER}" != "self" ]] && \
                   [[ "${SIGNER}" != "root-ca" ]] && \
                   [[ "${SIGNER}" != "intermediate-ca" ]]; then
                      fatal_error "Unknown signer \"$SIGNER\". Use self, root-ca, or intermediate-ca"
                fi
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
    command=$1
    failure_msg=$2
    output=$(${command} 2>&1)
    if [ $? -ne 0 ] ; then
        echo "Error, the following command failed:"
        echo $command
        echo "${output}"
        exit 1
    fi
}

function remove_file_if_it_exists ()
{
    description=$1
    file=$2
    if rm $file 2>/dev/null; then
        echo "Removed old ${description} file: ${file}"
    fi
}

function remove_old_keys_and_certificates ()
{
    remove_file_if_it_exists "server private key" server.key
    remove_file_if_it_exists "server certificate" server.crt
    remove_file_if_it_exists "client private key" client.key
    remove_file_if_it_exists "client certificate" client.crt
}

function create_private_key_and_self_signed_cert ()
{
    role=$1
    common_name=$2
    run_command "openssl \
                    req \
                    -newkey rsa:2048 \
                    -nodes \
                    -keyout ${role}.key \
                    -x509 \
                    -subj /C=US/ST=WA/L=Seattle/O=RemoteAutonomy/CN=${common_name} \
                    -out ${role}.crt" \
                "Could not create ${role} private key and self-signed certificate"
    echo "Created ${role} private key file: ${role}.key"
    echo "Created ${role} self-signed certificate file: ${role}.crt"
}

function create_server_private_key_and_self_signed_cert ()
{
    create_private_key_and_self_signed_cert server $SERVER_HOST
}

function create_client_private_key_and_self_signed_cert ()
{
    create_private_key_and_self_signed_cert client $CLIENT_HOST
}

parse_command_line_options $@
remove_old_keys_and_certificates
if [[ $CLEAN == $TRUE ]]; then
    exit 0
fi
if [[ "$AUTHENTICATION" == "server" ]] || [[ "$AUTHENTICATION" == "mutual" ]]; then
    create_server_private_key_and_self_signed_cert
fi
if [[ "$AUTHENTICATION" == "mutual" ]]; then
    create_client_private_key_and_self_signed_cert
fi
