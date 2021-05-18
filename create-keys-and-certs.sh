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

    mkdir -p admin

    {
        echo "[req]"
        echo "distinguished_name = req_distinguished_name"
        echo "prompt             = no"
        echo
        echo "[req_distinguished_name]"
        echo "countryName            = ${COUNTRY_NAME}"
        echo "stateOrProvinceName    = ${STATE_OR_PROVINCE_NAME}"
        echo "organizationName       = ${ORGANIZATION_NAME}"
        echo "organizationalUnitName = ${ORGANIZATIONAL_UNIT_NAME}"
        echo "commonName             = ${common_name}"
    } >admin/${role}_req.config

    run_command "openssl req \
                    -new \
                    -key keys/${role}.key \
                    -out admin/${role}.csr \
                    -config admin/${role}_req.config" \
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
        echo "copy_extensions = none"
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

    if [ $role == $signer_role ]; then
        maybe_self_sign="-selfsign"
    else
        maybe_self_sign=""
    fi

    run_command "openssl ca \
                    -batch \
                    -in admin/${role}.csr \
                    -out certs/${role}.crt \
                    -config admin/${signer_role}.config \
                    $maybe_self_sign \
                    -extfile admin/${role}_ca.ext \
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

function create_leaf_certificate ()
{
    role="$1"
    signer_role="$2"
    days="$3"

    mkdir -p certs

    if [ $role == $signer_role ]; then
        maybe_self_sign="-selfsign"
    else
        maybe_self_sign=""
    fi

    run_command "openssl ca \
                    -batch \
                    -in admin/${role}.csr \
                    -out certs/${role}.crt \
                    -config admin/${signer_role}.config \
                    $maybe_self_sign \
                    -days $days" \
                "Could not create ${role} certificate"

    echo "Created ${role} certificate"
}

function create_leaf_credentials ()
{
    role="$1"
    signer="$2"
    common_name="$3"
    days="$4"

    if [[ $signer == "self" ]]; then
        signer_role=$role
    else
        signer_role=$signer
    fi

    create_private_key $role
    create_certificate_signing_request $role "$common_name"
    create_leaf_certificate $role $signer_role $days

    if [[ $signer_role == "root" ]]; then
        cat certs/${role}.crt certs/root.crt >certs/${role}.pem
    elif [[ $signer_role == "intermediate" ]]; then
        cat certs/${role}.crt certs/intermediate.crt certs/root.crt >certs/${role}.pem
    elif [[ $signer_role == $role ]]; then
        cat certs/${role}.crt >certs/${role}.pem
    fi
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

# if [[ "$AUTHENTICATION" == "mutual" ]]; then
#     create_client_private_key_and_cert
# fi
# if [[ "$AUTHENTICATION" == "server" ]] || [[ "$AUTHENTICATION" == "mutual" ]]; then
#     create_server_private_key_and_cert
# fi

if [[ "$SIGNER" == "root" || "$SIGNER" == "intermediate" ]]; then
    create_ca_credentials root root "$ROOT_CA_COMMON_NAME" $ROOT_DAYS
fi

if [[ "$SIGNER" == "intermediate" ]]; then
    create_ca_credentials intermediate root "$INTERMEDIATE_CA_COMMON_NAME" $INTERMEDIATE_DAYS
fi

create_leaf_credentials client $SIGNER "$CLIENT_HOST" $LEAF_DAYS

create_leaf_credentials server $SIGNER "$SERVER_HOST" $LEAF_DAYS
