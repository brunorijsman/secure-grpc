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
SIGNER="self"

# TODO: Put country etc. in variables
ORGANIZATION="Example-Corp"
ROOT_CA_COMMON_NAME="${ORGANIZATION}-Root-Certificate-Authority"
INTERMEDIATE_CA_COMMON_NAME="${ORGANIZATION}-Intermediate-Certificate-Authority"
DAYS_VALID=3650

# TODO: Support subject alternative names (SAN)
# See https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/ for
# instructions on how to use config files to achieve that.

# TODO: Add support for -extfile

function help ()
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
    echo "  --authentication {none, server, mutual}, -a {none, server, mutual}"
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
    echo "  --signer {self, root, intermediate}, -i {self, root, intermediate}"
    echo "      self: server and client certificates are self-signed."
    echo "      root: server and client certificates are signed by the root CA."
    echo "      intermediate: server and client certificates are signed by an intermediate CA."
    echo "      (Default: self)"
    echo
    echo "  -x, --clean"
    echo "      Remove all private key and certificate files."
    echo
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
            --authentication|-a)
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
            --signer|-i)
                SIGNER="$2"
                shift
                if [[ "${SIGNER}" != "self" ]] && \
                   [[ "${SIGNER}" != "root" ]] && \
                   [[ "${SIGNER}" != "intermediate" ]]; then
                      fatal_error "Unknown signer \"$SIGNER\". Use self, root, or intermediate"
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

function empty_keys_and_certs_dirs ()
{
    rm -rf keys
    mkdir keys
    rm -rf certs
    mkdir certs
}

function create_private_key_and_self_signed_cert ()
{
    file_base="$1"
    common_name="$2"
    run_command "openssl \
                    req \
                    -newkey rsa:2048 \
                    -nodes \
                    -keyout keys/${file_base}.key \
                    -x509 \
                    -subj /C=US/ST=WA/L=Seattle/O=${ORGANIZATION}/CN=${common_name} \
                    -days ${DAYS_VALID} \
                    -out certs/${file_base}.crt" \
                "Could not create ${file_base} private key and self-signed certificate"
    echo "Created ${file_base} private key file: ${file_base}.key"
    echo "Created ${file_base} self-signed certificate file: ${file_base}.crt"
}

function create_private_key_and_ca_signed_cert ()
{
    file_base="$1"
    common_name="$2"
    signing_ca="$3"
    signing_ca_certificate="${signing_ca}.crt"
    signing_ca_private_key="${signing_ca}.key"
    # Create the private key (.key) and certificate signing request (.csr)
    run_command "openssl \
                    req \
                    -newkey rsa:2048 \
                    -nodes \
                    -keyout keys/${file_base}.key \
                    -subj /C=US/ST=WA/L=Seattle/O=${ORGANIZATION}/CN=${common_name} \
                    -out certs/${file_base}.csr" \
                "Could not create ${file_base} private key and certificate signing request"
    echo "Created ${file_base} private key file: ${file_base}.key"
    echo "Created ${file_base} certificate signing request file: ${file_base}.csr"
    # Create the CA-signed certificate
    run_command "openssl \
                    x509 \
                    -req \
                    -in certs/${file_base}.csr \
                    -CA certs/${signing_ca_certificate} \
                    -CAkey keys/${signing_ca_private_key} \
                    -CAcreateserial \
                    -days ${DAYS_VALID} \
                    -out certs/${file_base}.crt" \
                "Could not create ${file_base} certificate"
    echo "Created ${file_base} certificate file: ${file_base}.crt"
}

function create_root_ca_private_key_and_cert ()
{
    create_private_key_and_self_signed_cert root "$ROOT_CA_COMMON_NAME"
}

function create_intermediate_ca_private_key_and_cert ()
{
    create_private_key_and_ca_signed_cert intermediate "$INTERMEDIATE_CA_COMMON_NAME" root
}

function create_server_private_key_and_cert ()
{
    if [[ "$SIGNER" == "root" ]]; then
        create_private_key_and_ca_signed_cert server "$SERVER_HOST" root
    elif [[ "$SIGNER" == "intermediate" ]]; then
        create_private_key_and_ca_signed_cert server "$SERVER_HOST" intermediate
    elif [[ "$SIGNER" == "self" ]]; then
        create_private_key_and_self_signed_cert server "$SERVER_HOST"
    else
        fatal_error "Unknown signer \"${SIGNER}\""
    fi
}

function create_client_private_key_and_cert ()
{
    if [[ "$SIGNER" == "root" ]]; then
        create_private_key_and_ca_signed_cert client "$CLIENT_HOST" root
    elif [[ "$SIGNER" == "intermediate" ]]; then
        create_private_key_and_ca_signed_cert client "$CLIENT_HOST" intermediate
    elif [[ "$SIGNER" == "self" ]]; then
        create_private_key_and_self_signed_cert client "$CLIENT_HOST"
    else
        fatal_error "Unknown signer \"${SIGNER}\""
    fi
}

parse_command_line_options $@
empty_keys_and_certs_dirs
if [[ $CLEAN == $TRUE ]]; then
    exit 0
fi
if [[ "$SIGNER" == "root" ]] || [[ "$SIGNER" == "intermediate" ]]; then
    create_root_ca_private_key_and_cert
fi
if [[ "$SIGNER" == "intermediate" ]]; then
    create_intermediate_ca_private_key_and_cert
fi
if [[ "$AUTHENTICATION" == "mutual" ]]; then
    create_client_private_key_and_cert
fi
if [[ "$AUTHENTICATION" == "server" ]] || [[ "$AUTHENTICATION" == "mutual" ]]; then
    create_server_private_key_and_cert
fi
