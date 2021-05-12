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
    remove_file_if_it_exists "server private key" "server.key"
    remove_file_if_it_exists "server certificate" "server.crt"
}

function create_server_key_and_self_signed_cert {
    remove_old_keys_and_certificates
    run_command "openssl \
                    req \
                    -newkey rsa:2048 \
                    -nodes \
                    -keyout server.key \
                    -x509 \
                    -subj /C=US/ST=WA/L=Seattle/O=RemoteAutonomy/CN=${COMMON_NAME} \
                    -out server.crt" \
                "Could not create server private key and self-signed certificate"
    echo "Created server private key file: server.key"
    echo "Created server self-signed certificate file: server.crt"
}

create_server_key_and_self_signed_cert
