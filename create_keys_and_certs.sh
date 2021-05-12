#!/bin/bash

COMMON_NAME="localhost"

function run_command {
    command=$1
    failure_msg=$2
    output=$(${command} 2>&1)
    if [ $? -ne 0 ] ; then
        echo "FAILED!"
        echo $command
        echo "${output}"
        exit 1
    fi
}

function remove_file_if_it_exists {
    description=$1
    file=$2
    if rm $file 2>/dev/null; then
        echo "Removed old ${description} file: ${file}"
    fi
}

function remove_old_keys_and_certificates {
    remove_file_if_it_exists "server private key" server.key
    remove_file_if_it_exists "server certificate" server.crt
    remove_file_if_it_exists "client private key" client.key
    remove_file_if_it_exists "client certificate" client.crt
}

function create_private_key_and_self_signed_cert {
    role=$1
    run_command "openssl \
                    req \
                    -newkey rsa:2048 \
                    -nodes \
                    -keyout ${role}.key \
                    -x509 \
                    -subj /C=US/ST=WA/L=Seattle/O=RemoteAutonomy/CN=${COMMON_NAME} \
                    -out ${role}.crt" \
                "Could not create ${role} private key and self-signed certificate"
    echo "Created ${role} private key file: ${role}.key"
    echo "Created ${role} self-signed certificate file: ${role}.crt"
}

function create_server_private_key_and_self_signed_cert {
    create_private_key_and_self_signed_cert server
}

function create_client_private_key_and_self_signed_cert {
    create_private_key_and_self_signed_cert client
}

remove_old_keys_and_certificates
create_server_private_key_and_self_signed_cert
create_client_private_key_and_self_signed_cert
