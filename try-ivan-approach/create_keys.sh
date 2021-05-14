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
    -in root.csr \
    -out root.pem \
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
    -in intermediate.csr \
    -out intermediate.pem \
    -config root.config \
    -extfile ca.ext \
    -days 730

# create the private key for the leaf certificate
openssl genrsa \
    -out leaf.key \
    2048

# create the csr for the leaf certificate
openssl req \
    -new \
    -key leaf.key \
    -out leaf.csr \
    -config leaf_req.config

# create the leaf certificate (note: no ca.ext. this certificate is not a CA)
openssl ca \
    -in leaf.csr \
    -out leaf.pem \
    -config intermediate.config \
    -days 365

# verify the certificate chain
openssl verify \
    -x509_strict \
    -CAfile root.pem \
    -untrusted intermediate.pem \
    leaf.pem

