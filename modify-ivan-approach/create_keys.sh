#!/bin/bash

# create the private key for the root CA
openssl genrsa \
    -out root.key \
    2048

# create the csr for the root CA
openssl req \
    -new \
    -key root.key \
    -out root.csr \
    -config root_req.config

# create the root CA cert
openssl ca \
    -batch \
    -in root.csr \
    -out root.crt \
    -config root.config \
    -selfsign \
    -extfile ca.ext \
    -days 1095

# create the private key for the intermediate CA
openssl genrsa \
    -out intermediate.key \
    2048

# create the csr for the intermediate CA
openssl req \
    -new \
    -key intermediate.key \
    -out intermediate.csr \
    -config intermediate_req.config

# create the intermediate CA cert
openssl ca \
    -batch \
    -in intermediate.csr \
    -out intermediate.crt \
    -config root.config \
    -extfile ca.ext \
    -days 730

# create the private key for the client certificate
openssl genrsa \
    -out client.key \
    2048

# create the csr for the client certificate
openssl req \
    -new \
    -key client.key \
    -out client.csr \
    -config client_req.config

# create the client certificate (note: no ca.ext. this certificate is not a CA)
openssl ca \
    -batch \
    -in client.csr \
    -out client.crt \
    -config intermediate.config \
    -days 365

# verify the certificate chain
openssl verify \
    -x509_strict \
    -CAfile root.crt \
    -untrusted intermediate.crt \
    client.crt

# create the private key for the server certificate
openssl genrsa \
    -out server.key \
    2048

# create the csr for the server certificate
openssl req \
    -new \
    -key server.key \
    -out server.csr \
    -config server_req.config

# create the server certificate (note: no ca.ext. this certificate is not a CA)
openssl ca \
    -batch \
    -in server.csr \
    -out server.crt \
    -config intermediate.config \
    -days 365

# verify the certificate chain
openssl verify \
    -x509_strict \
    -CAfile root.crt \
    -untrusted intermediate.crt \
    server.crt



