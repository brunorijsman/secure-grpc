#!/bin/bash

# Copyright 2021 Bruno Rijsman
# Apache License Version 2.0; see LICENSE for details

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
WRONG_KEY="none"

COUNTRY_NAME="US"
STATE_OR_PROVINCE_NAME="WA"
ORGANIZATION_NAME="Example Corp"
ORGANIZATIONAL_UNIT_NAME="Engineering"
ROOT_CA_COMMON_NAME="${ORGANIZATION_NAME} Root Certificate Authority"
INTERMEDIATE_CA_COMMON_NAME="${ORGANIZATION_NAME} Intermediate Certificate Authority"
ROOT_DAYS=1095
INTERMEDIATE_DAYS=730
LEAF_DAYS=365

# TODO: Support subject alternative names (SAN)
# See https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/ for
# instructions on how to use config files to achieve that.

function help ()
{
    echo
    echo "SYNOPSIS"
    echo
    echo "    create-keys-and-certs.sh [OPTION]..."
    echo
    echo "DESCRIPTION"
    echo
    echo "  Generate a set of private keys and certificates for the gRPC server and (if mutual"
    echo "  authentication is used) also for the gRPC client. The certificates can be self-signed,"
    echo "  or signed by a root CA, or signed by an intermediate CA. For negative testing, it is"
    echo "  possible to purposely generate a wrong private key (one that does not match the"
    echo "  public key in the certificate)."
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
    echo "      Who signs the certificates:"
    echo "      self: server and client certificates are self-signed."
    echo "      root: server and client certificates are signed by the root CA."
    echo "      intermediate: server and client certificates are signed by an intermediate CA; and"
    echo "      the intermediate CA certificate is signed by the root CA."
    echo "      (Default: self)"
    echo
    echo "  -x, --clean"
    echo "      Remove all private key and certificate files."
    echo
    echo -n "  --wrong-key {none, server, client, intermediate, root}"
    echo " -w {none, server, client, intermediate, root}"
    echo "      Generate an incorrect private key (this is used for negative testing):"
    echo "      none: don't generate an incorrect private key; all private keys are correct."
    echo "      server: generate an incorrect private key for the server."
    echo "      client: generate an incorrect private key for the client."
    echo "      root: generate an incorrect private key for the root CA."
    echo "      intermediate: generate an incorrect private key for the intermediate CA."
    echo "      (Default: none)"
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
            --wrong-key|-w)
                WRONG_KEY="$2"
                shift
                if [[ "${WRONG_KEY}" != "none" ]] && \
                   [[ "${WRONG_KEY}" != "server" ]] && \
                   [[ "${WRONG_KEY}" != "client" ]] && \
                   [[ "${WRONG_KEY}" != "root" ]] && \
                   [[ "${WRONG_KEY}" != "intermediate" ]]; then
                      msg="Unknown wrong-key \"$WRONG_KEY\". "
                      msg="$msg Use server, client, root, or intermediate"
                      fatal_error "$msg"
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
    command="$1"
    failure_msg="$2"
    output=$(${command} 2>&1)
    if [ $? -ne 0 ] ; then
        echo "${RED}Error:${NORMAL} $failure_msg:"
        echo "The following command failed:"
        echo "${BLUE}${command}${NORMAL}"
        echo "The output of the command was:"
        echo "${BLUE}${output}${NORMAL}"
        exit 1
    fi
}

function clean_previous_run ()
{
    rm -rf keys
    mkdir keys
    rm -rf certs
    mkdir certs
    rm -rf admin
    mkdir admin
}

function create_private_key ()
{
    role="$1"
    mkdir -p keys
    run_command "openssl genrsa \
                    -out keys/${role}.key \
                    2048" \
                "Could not create ${role} private key"

    echo "Created ${role} private key"
}

function create_certificate_signing_request ()
{
    role="$1"
    common_name="$2"
    dns_name="$3"

    mkdir -p admin

    {
        echo "[req]"
        echo "distinguished_name = req_distinguished_name"
        echo "req_extensions     = req_ext"
        echo "prompt             = no"
        echo
        echo "[req_distinguished_name]"
        echo "countryName            = ${COUNTRY_NAME}"
        echo "stateOrProvinceName    = ${STATE_OR_PROVINCE_NAME}"
        echo "organizationName       = ${ORGANIZATION_NAME}"
        echo "organizationalUnitName = ${ORGANIZATIONAL_UNIT_NAME}"
        echo "commonName             = ${common_name}"
        echo
        echo "[req_ext]"
        if [[ $dns_name != "" ]]; then
            echo "subjectAltName = @alt_names"
            echo
            echo "[alt_names]"
            echo "DNS.1 = ${dns_name}"
        fi
    } >admin/${role}_req.config

    run_command "openssl req \
                    -new \
                    -text \
                    -key keys/${role}.key \
                    -out admin/${role}.csr \
                    -config admin/${role}_req.config \
                    -extensions req_ext" \
                "Could not create ${role} certificate signing request"

    echo "Created ${role} certificate signing request"
}

function create_ca_certificate ()
{
    role="$1"
    signer_role="$2"
    days="$3"

    mkdir -p admin
    mkdir -p admin/${role}

    > admin/${role}/database
    > admin/${role}/index
    echo "00" >admin/${role}/serial

    {
        echo "[ca]"
        echo "default_ca      = CA_default"
        echo
        echo "[CA_default]"
        echo "database        = admin/${role}/database"
        echo "new_certs_dir   = admin/${role}"
        echo "certificate     = certs/${role}.crt"
        echo "serial          = admin/${role}/serial"
        echo "private_key     = keys/${role}.key"
        echo "policy          = policy_any"
        echo "email_in_dn     = no"
        echo "unique_subject  = no"
        echo "copy_extensions = copy"
        echo "default_md      = sha256"
        echo
        echo "[policy_any]"
        echo "countryName            = optional"
        echo "stateOrProvinceName    = optional"
        echo "organizationName       = optional"
        echo "organizationalUnitName = optional"
        echo "commonName             = supplied"
    } >admin/${role}.config

    {
        echo "[default]"
        echo "basicConstraints = critical,CA:true"
        echo "keyUsage         = critical,keyCertSign"
    } >admin/${role}_ca.ext

    if [[ $signer_role == "self" || $signer_role == $role ]]; then
        maybe_self_sign="-selfsign"
    else
        maybe_self_sign=""
    fi

    run_command "openssl ca \
                    -batch \
                    -in admin/${role}.csr \
                    -out certs/${role}.crt \
                    -config admin/${signer_role}.config \
                    -extfile admin/${role}_ca.ext \
                    $maybe_self_sign \
                    -days $days" \
                "Could not create ${role} certificate"

    echo "Created ${role} certificate"
}

function create_ca_credentials ()
{
    role="$1"
    signer_role="$2"
    common_name="$3"
    days="$4"

    create_private_key $role
    create_certificate_signing_request $role "$common_name"
    create_ca_certificate $role $signer_role $days
}

function create_leaf_ca_signed_certificate ()
{
    role="$1"
    signer_role="$2"
    days="$3"

    mkdir -p certs

    {
        echo "[default]"
        echo "basicConstraints = critical, CA:false"
        echo "keyUsage         = critical, digitalSignature, keyEncipherment"
    } >admin/${role}_leaf.ext

    run_command "openssl ca \
                    -batch \
                    -in admin/${role}.csr \
                    -out certs/${role}.crt \
                    -config admin/${signer_role}.config \
                    -extfile admin/${role}_leaf.ext \
                    -days $days" \
                "Could not create ${role} certificate"

    echo "Created ${role} certificate"
}

function create_leaf_private_key_and_self_signed_certificate ()
{
    role="$1"
    common_name="$2"
    days="$3"

    mkdir -p certs
    mkdir -p admin

    {
        echo "[req]"
        echo "distinguished_name = req_distinguished_name"
        echo "req_extensions     = req_ext"
        echo "prompt             = no"
        echo
        echo "[req_distinguished_name]"
        echo "countryName            = ${COUNTRY_NAME}"
        echo "stateOrProvinceName    = ${STATE_OR_PROVINCE_NAME}"
        echo "organizationName       = ${ORGANIZATION_NAME}"
        echo "organizationalUnitName = ${ORGANIZATIONAL_UNIT_NAME}"
        echo "commonName             = ${common_name}"
        echo
        echo "[req_ext]"
        echo "subjectAltName = @alt_names"
        echo
        echo "[alt_names]"
        echo "DNS.1 = ${common_name}"
    } >admin/${role}_req.config

    run_command "openssl req \
                    -x509 \
                    -nodes \
                    -text \
                    -newkey rsa:4096 \
                    -keyout keys/${role}.key \
                    -out certs/${role}.crt \
                    -config admin/${role}_req.config \
                    -extensions req_ext \
                    -days $days" \
                "Could not create ${role} certificate"

    echo "Created ${role} certificate (self-signed)"
}

function create_leaf_certificate_chain ()
{
    role="$1"
    signer_role="$2"

    if [[ $signer_role == "root" ]]; then
        cat certs/${role}.crt certs/root.crt >certs/${role}.pem
    elif [[ $signer_role == "intermediate" ]]; then
        cat certs/${role}.crt certs/intermediate.crt certs/root.crt >certs/${role}.pem
    else
        cat certs/${role}.crt >certs/${role}.pem
    fi

    echo "Created ${role} certificate chain"
}

function create_leaf_credentials ()
{
    role="$1"
    signer_role="$2"
    common_name="$3"
    days="$4"

    if [[ $signer_role == "self" || $signer_role == $role ]]; then
        create_leaf_private_key_and_self_signed_certificate $role "$common_name" $days
    else
        create_private_key $role
        create_certificate_signing_request $role "$common_name" "$common_name"
        create_leaf_ca_signed_certificate $role $signer_role $days
    fi

    create_leaf_certificate_chain $role $signer_role
}

parse_command_line_options $@

clean_previous_run
if [[ $CLEAN == $TRUE ]]; then
    echo "All generated files from previous runs removed"
    exit 0
fi
if [[ "$AUTHENTICATION" == "none" ]]; then
    echo "No authentication (no keys or certificates generated)"
    exit 0
fi

if [[ "$SIGNER" == "root" || "$SIGNER" == "intermediate" ]]; then
    create_ca_credentials root root "$ROOT_CA_COMMON_NAME" $ROOT_DAYS
fi

if [[ "$SIGNER" == "intermediate" ]]; then
    create_ca_credentials intermediate root "$INTERMEDIATE_CA_COMMON_NAME" $INTERMEDIATE_DAYS
fi

create_leaf_credentials server $SIGNER "$SERVER_HOST" $LEAF_DAYS

if [[ "$AUTHENTICATION" == "mutual" ]]; then
    create_leaf_credentials client $SIGNER "$CLIENT_HOST" $LEAF_DAYS
fi

case $WRONG_KEY in
    none)
        ;;
    server)
        create_private_key server
        ;;
    client)
        create_private_key client
        ;;
    root)
        create_ca_credentials root root "$ROOT_CA_COMMON_NAME" $ROOT_DAYS
        create_leaf_certificate_chain server $SIGNER
        if [[ "$AUTHENTICATION" == "mutual" ]]; then
            create_leaf_certificate_chain client $SIGNER
        fi
        ;;
    intermediate)
        create_ca_credentials intermediate root "$INTERMEDIATE_CA_COMMON_NAME" $INTERMEDIATE_DAYS
        create_leaf_certificate_chain server $SIGNER
        if [[ "$AUTHENTICATION" == "mutual" ]]; then
            create_leaf_certificate_chain client $SIGNER
        fi
        ;;
esac

