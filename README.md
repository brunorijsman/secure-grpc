# Securing Google Remote Procedure Calls (gRPC)

This repository contains the following example code for securing Google Remote Procedure Calls
(gRPC):

* A simple gRPC server that can authenticate itself and (optionally) the client.

* A simple gRPC client that can authenticate the server.

* Both the server and the client are implemented in Python using asynchronous input/out (aio).

* A test scripts that automatically tests all possible authentication schemes. It tests not only
  that authentication accepts the connection when the keys and certificates are correct, but also
  that authentication rejects the connection when the keys or the certificates are incorrect.

* A script for generating the correct keys and certificates for a given authentication scheme.

# Authentication Schemes

Our code supports multiple authentication schemes. The scheme is determined by the combination of
the parameters listed below. 
The test script (which is described in detail later) tests all possible parameter combinations.

## Authenticated Parties

The authenticated parties can be:

* **None**: There is no authentication. The client does not authenticate the server, and the server
  does not authenticate the client. But the connection is still encrypted using TLS.

* **Server**: The client authenticates the server (i.e. the server is the authenticated party) but
  the server does not authenticate the client. This is the most common usage of TLS for human
  web-browsing.

* **Mutual**: The client authenticate the server and the server also authenticates the server (but
  also see "client name check" below). This is referred to as mutual TLS (mTLS) and it is typically
  used for machine-to-machine APIs.

## Certificate Signer

The client uses the server certificate to authenticate the server, and the server uses the client
certificate to authenticate the client.
In both cases, checking the signature on the certificate is a crucial step in checking the validity
of the certificate.

The certificate signer can be:

* **Self-signed**: The certificate can be self-signed. In this case the private key corresponding to
  the public in the certificate is used to sign the certificate. The operator must install the
  certificate of each trusted server on the client. And vice versa, for mutual authentication, the
  operator must install the certificate of each trusted client on the server.

* **Certificate Authority (CA) signed** The certificate is signed by a Certificate Authority (CA).
  This big advantage of this approach is that the operator only needs to install the root CA
  certificate on each server and client.
  There are several variations on this:

  * The certificate of the leaf (i.e. the certificate of the server or the client) is directly
    signed by the **root** CA. In other words, the certificate chain length is 2.

  * The certificate of the leaf is signed by an **intermediate** CA and the certificate of the
    intermediate CA is signed by the root CA. In other words, the certificate chain length is 3.

  * There can be multiple levels of intermediate CAs. In other words, the certificate chain length
    is 4 or more.

Our server and client code support all of the above variations. However, our script for generating
certificates and our script for automated testing only support certificate chain lengths up to and
including 3.

Our code generates a self-signed root CA certificate. In other words, we don't rely on the list
of trusted public root CAs that is pre-installed on the computer (e.g. in the key chain in macOS).
This allows our code to sign leaf and intermediate CA certificates (it would be impractical and
expensive to have a public CA sign our certificates, although it has gotten easier since
[Encryption Everywhere](https://www.websecurity.digicert.com/theme/encryption-everywhere)
was introduced).
Using self-signed "private" root CAs is common for accessing resources (such as APIs) within the
context of an enterprise. 

## Server Name Check

When the client authenticates the server, it can perform the **server name check** in one of two
ways:

* The client verifies that the server name in the certificate matches the DNS host name of the
  server. This default behavior of TLS. We refer to this as **server host naming** in our code.

* The client uses the TLS **Server Name Indication** (SNI) option to explicitly choose the server
  name to be authenticated.
  Historically, this was typically used when multiple different web sites where hosted on a single
  web server.
  The web server used the SNI option to present the correct certificate to the client.
  In the context of APIs, it allows us to decouple the naming of service from hosts.
  Hence, we refer to this as **server service naming** in our code.

Note: our code stores and checks the authenticated name of a leaf in both the Common Name (CN) field
of the certificate (for compatibility with older code) and in the Subject Alternative Name (SAN)
field of the certificate (for compatibility with newer code that insists on it).

## Client Name Check

When a server authenticates a client, i.e. when using mutual TLS (mTLS), by default the server only
validates whether the certificate presented by the client is properly signed by a trusted
certificate authority.
If the certificate is self-signed, this means that the client certificate must be pre-installed on
the server.
Either way, by default, the server does _not_ check the name of the client in the certificate. 

This behavior can be overridden in our code. 
The server code can check whether the name of the client (which is present in the validated
certificate presented by the client) matches a pre-configured list of trusted client names.
We refer to this as the optional **client name check**.

## Authentication Protocol

[Google RPC supports the following authentication protocols](https://grpc.io/docs/guides/auth/):

* [Transport Layer Security (**TLS**)](https://datatracker.ietf.org/doc/html/rfc8446),
  also known by its former and deprecated name Secure Sockets Layer (SSL). 
  This is a widely used standard protocol for providing authentication and encryption
  at the transport (TCP) layer. It is the underlying protocol for secure application layer
  protocols such as HTTPS. In many use cases (e.g. secure web browsing) TLS is only used for the
  client to authenticate the server and for encryption. In such cases, some other mechanism (e.g.
  a username and a password or a two-factor authentication hardware token) is used for the server
  to authenticate the client.

* Mutual TLS (**mTLS**). When TLS is used for application-to-application communications (as opposed
  to human-to-application communications) it is common to use TLS for both parties to authenticate
  each other. Not only does the client authenticate the server, but the server also authenticates
  the client.
  mTLS is not really a separate protocol; it is just a specific way of using TLS.

* [Application Layer Transport Security (**ALTS**)](https://cloud.google.com/security/encryption-in-transit/application-layer-transport-security) 
  is a mutual authentication and transport encryption system developed by Google and typically used
  for securing Remote Procedure Call (RPC) communications within Google's infrastructure. ALTS 
  is similar in concept to mTLS but has been designed and optimized to meet the needs of Google's
  datacenter environments.

* GRPC also supports **token-based authentication** which is intended to be used in Google APIs
  (e.g. APIs in Google Cloud Platform).

We currently only support TLS and mTLS version 1.3. We do not yet support ALTS or tokens.

# Using the Example Code

## Prerequisites

You must have to following software installed on your computer to run the software in this
repository.

Make sure that `git` is installed:

<pre>
$ <b>git --version</b>
git version 2.29.2
</pre>

Make sure that `Python` version 3.8 or later is installed:

<pre>
$ <b>python --version</b>
Python 3.8.7
</pre>

Make sure that `pip` is installed:

<pre>
$ <b>pip --version</b>
pip 20.2.3 from /Users/brunorijsman/.pyenv/versions/3.8.7/lib/python3.8/site-packages/pip (python 3.8)
</pre>

Make sure `OpenSSL` is installed (in this output we see `LibreSSL` which is a particular flavor of
`OpenSSL`):

<pre>
$ <b>openssl version</b>
LibreSSL 2.8.3
</pre>

Our test script uses [Docker](https://www.docker.com/) to test running the server and client in 
different hosts.
If you don't have Docker installed, you can skip the Docker-based test cases using the
`--skip-docker` command-line option for the test script.
To check if Docker is installed:

<pre>
$ <b>docker --version</b>
Docker version 19.03.8, build afacb8b
</pre>

Our test script uses the [Evans](https://github.com/ktr0731/evans), which is an interactive gRPC
client, to test interoperability with third-party software.
If you don't have Evans installed, you can skip the Evans-based test cases using the
`--skip-evans` command-line option for the test script.
To check if Evans is installed:

<pre>
$ <b>evans --version</b>
evans 0.9.3
</pre>

## Installation Instructions

The steps to install the code are as follows. We have tested these steps on macOS 10.15.7 Catalina
and on Linux Ubuntu 20.04 Focal Fossa but they should work on other UNIX-ish platforms as well.

Clone this GitHub repository:

<pre>
$ <b>git clone https://github.com/brunorijsman/secure-grpc.git</b>
Cloning into 'secure-grpc'...
remote: Enumerating objects: 427, done.
remote: Counting objects: 100% (427/427), done.
remote: Compressing objects: 100% (282/282), done.
remote: Total 427 (delta 254), reused 290 (delta 119), pack-reused 0
Receiving objects: 100% (427/427), 88.95 KiB | 1023.00 KiB/s, done.
Resolving deltas: 100% (254/254), done.
</pre>

Change directory to the cloned repo:

<pre>
$ <b>cd secure-grpc</b>
</pre>

Create and activate a Python virtual environment:

<pre>
$ <b>python -m venv venv</b>
$ <b>source venv/bin/activate</b>
(venv) $
</pre>

Install the Python dependencies:

<pre>
(venv) $ <b>pip install -r requirements.txt</b>
Collecting astroid==2.5.6
  Using cached astroid-2.5.6-py3-none-any.whl (219 kB)
[...]
    Running setup.py install for grpc-status ... done
Successfully installed astroid-2.5.6 asyncio-3.4.3 googleapis-common-protos-1.53.0 grpc-status-0.0.1 grpcio-1.38.0 grpcio-status-1.38.0 grpcio-tools-1.37.1 isort-5.8.0 lazy-object-proxy-1.6.0 mccabe-0.6.1 mypy-0.812 mypy-extensions-0.4.3 protobuf-3.16.0 pylint-2.8.2 six-1.16.0 toml-0.10.2 typed-ast-1.4.3 typing-extensions-3.10.0.0 wrapt-1.12.1
</pre>

If you get a warning about a new version if `pip` being available you may ignore it or you can 
upgrade `pip`:

<pre>
(venv) $ <b>pip install --upgrade pip</b>
Collecting pip
  Using cached pip-21.1.2-py3-none-any.whl (1.5 MB)
Installing collected packages: pip
  Attempting uninstall: pip
    Found existing installation: pip 20.2.3
    Uninstalling pip-20.2.3:
      Successfully uninstalled pip-20.2.3
Successfully installed pip-21.1.2
</pre>

You have completed the installation.
To make sure the installation was successful you can invoke the server
help:

<pre>
(venv) $ <b>./server.py --help</b>
usage: server.py [-h] [--authentication {none,server,mutual}] [--client-name CLIENT_NAME] [--server-host SERVER_HOST] [--server-port SERVER_PORT] [--signer {self,ca}]

Secure gRPC demo server
[...]
</pre>

## Running the Server

The server runs a simple gRPC service for adding numbers
(we describe the implementation in detail later).
It waits for requests from clients to add two numbers, and returns the result.

Use the `--help` command line option to see what command-line options are available and what their
meaning is:

<pre>
(venv) $ <b>./server.py --help</b>
usage: server.py [-h] [--authentication {none,server,mutual}] [--client-name CLIENT_NAME] [--server-host SERVER_HOST] [--server-port SERVER_PORT] [--signer {self,ca}]

Secure gRPC demo server

optional arguments:
  -h, --help            show this help message and exit
  --authentication {none,server,mutual}, -a {none,server,mutual}
                        Authentication: none, server, or mutual (default: none)
  --client-name CLIENT_NAME, -C CLIENT_NAME
                        Only allow specified client name to connect (default: allow any client)
  --server-host SERVER_HOST, -s SERVER_HOST
                        The server host name (default: localhost)
  --server-port SERVER_PORT, -p SERVER_PORT
                        The server port (default: 50051)
  --signer {self,ca}, -i {self,ca}
                        Signer for server and client certificates: self or ca (certificate authority) (default: self)
</pre>

For now, we will start the server without any command-line options.
The default behavior is to _not_ do any authentication, so we don't need to create any keys or
certificates before starting the server.
We will see example with authentication later on.

<pre>
(venv) <b>$ ./server.py</b>
Server: No authentication
Server: listening on localhost:50051
</pre>

The output indicates that:
* There is no authentication.
* The server is running on DNS host name `localhost` and listening on TCP port `50051` for incoming
  requests from the client.

You will not your shell prompt back as the server is a long-running process waiting for incoming
client requests.

You will need to start another terminal shell for starting the client. Don't forget to activate
the virtual environment again in the new terminal:

<pre>
$ <b>cd secure-grpc</b>
$ <b>source venv/bin/activate</b>
(venv) $
</pre>

Or you will need to run the server in as a background process:

<pre>
(venv) $ <b>./server.py &</b>
[1] 73734
Server: No authentication
Server: listening on localhost:50051
(venv) $ 
</pre>

If you start the server as a background process, you can stop the server by killing it:

<pre>
(venv) $ <b>ps</b>
  PID TTY           TIME CMD
 2882 ttys000    0:00.59 -bash
34500 ttys003    0:00.08 -bash
73734 ttys003    0:00.17 python ./server.py
(venv) $ <b>kill 73734</b>
[1]+  Terminated: 15          ./server.py
(venv) $
</pre>

For now, leave the server running so that we can start the client.

## Running the Client

The client invokes the gRPC service provided by the server.
When you start the client, it sends a request to add two random numbers to the server, waits for the
result to come pack, prints the result, and then terminates (the server keeps running).

Use the `--help` command-line option to see what command-line options are available and what their
meaning is:

<pre>
(venv) $ <b>./client.py --help</b>
usage: client.py [-h] [--authentication {none,server,mutual}] [--server-host SERVER_HOST] [--server-name SERVER_NAME] [--server-port SERVER_PORT] [--signer {self,ca}]

Secure gRPC demo client

optional arguments:
  -h, --help            show this help message and exit
  --authentication {none,server,mutual}, -a {none,server,mutual}
                        Authentication: none, server, or mutual (default: none)
  --server-host SERVER_HOST, -s SERVER_HOST
                        The server host name (default: localhost)
  --server-name SERVER_NAME, -S SERVER_NAME
                        Server name override, if different from the server host name
  --server-port SERVER_PORT, -p SERVER_PORT
                        The server port (default: 50051)
  --signer {self,ca}, -i {self,ca}
                        Signer for server and client certificates: self or ca (certificate authority) (default: self)
</pre>

Once again, for now, we will run the client without any command line options (we are assuming that
the server is still running, as described above).

<pre>
(venv) $ ./client.py
Client: No authentication
Client: connect to localhost:50051
Client: 4648 + 6355 = 11003
</pre>

The client output indicates that:
* The client initiated a gRPC session to the server running host host name `localhost` and TCP port
  `50051`, without authentication.
* The client picked two random numbers, sent a request to the server to add them, waiting for the
  result, and printed the result.

Meanwhile, the server prints the received request and result:

<pre>
Server: 4648 + 6355 = 11003
</pre>

Next, we will show how to run the server and client with authentication enabled, but first we have
to explain the script that generates keys and certificates.

## Generating Keys and Certificates.

The `create-keys-and-certs.sh` bash shell script automates the generation of keys and certificates
for the server, the client, and certificate authorities (CAs).

Internally, it uses the `openssl` command line utility. We describe the implementation in more
detail later.

Use the `--help` command-line option to see what command-line options are available and what their
meaning is:

<pre>
(venv) $ <b>./create-keys-and-certs.sh --help</b>

SYNOPSIS

    create-keys-and-certs.sh [OPTION]...

DESCRIPTION

  Generate a set of private keys and certificates for the gRPC server and (if mutual
  authentication is used) also for the gRPC client. The certificates can be self-signed,
  or signed by a root CA, or signed by an intermediate CA. For negative testing, it is
  possible to purposely generate a wrong private key (one that does not match the
  public key in the certificate).

OPTIONS

  --help, -h, -?
      Print this help and exit

  --authentication {none, server, mutual}, -a {none, server, mutual}
      none: no authentication.
      server: the client authenticates the server.
      mutual: the client and the server mutually authenticate each other.
      (Default: none)

  --client-name, -c
      The client hostname. Default: localhost.

  --server-name, -s
      The server hostname. Default: localhost.

  --signer {self, root, intermediate}, -i {self, root, intermediate}
      Who signs the certificates:
      self: server and client certificates are self-signed.
      root: server and client certificates are signed by the root CA.
      intermediate: server and client certificates are signed by an intermediate CA; and
      the intermediate CA certificate is signed by the root CA.
      (Default: self)

  -x, --clean
      Remove all private key and certificate files.

  --wrong-key {none, server, client, intermediate, root} -w {none, server, client, intermediate, root}
      Generate an incorrect private key (this is used for negative testing):
      none: don't generate an incorrect private key; all private keys are correct.
      server: generate an incorrect private key for the server.
      client: generate an incorrect private key for the client.
      root: generate an incorrect private key for the root CA.
      intermediate: generate an incorrect private key for the intermediate CA.
      (Default: none)
</pre>

The script generates the following files:

* The `certs` subdirectory contains all generated certificates (`.crt` files) and certificate chains
  (`.pem` files).

* The `keys` subdirectory contains all generated private keys (`.key` files).

* The `admin` subdirectory contains various files that are generated in the process of generating
  the files, such as OpenSSL configuration files (`.config` and `.ext` files), certificate signing
  requests (`.csr` files), etc. 

Here is an example of the contents of these directories after generating keys and certificates for
the server, the client, a root CA, and an intermediate CA:

<pre>
(venv) $ <b>./create-keys-and-certs.sh --authentication mutual --signer intermediate</b>
Created root private key
Created root certificate signing request
Created root certificate
Created intermediate private key
Created intermediate certificate signing request
Created intermediate certificate
Created server private key
Created server certificate signing request
Created server certificate
Created server certificate chain
Created client private key
Created client certificate signing request
Created client certificate
Created client certificate chain
</pre>

<pre>
(venv) $ <b>tree certs keys admin</b>
certs
├── client.crt
├── client.pem
├── intermediate.crt
├── root.crt
├── server.crt
└── server.pem
keys
├── client.key
├── intermediate.key
├── root.key
└── server.key
admin
├── client.csr
├── client_leaf.ext
├── client_req.config
├── intermediate
│   ├── 00.pem
│   ├── 01.pem
│   ├── database
│   ├── database.attr
│   ├── database.attr.old
│   ├── database.old
│   ├── index
│   ├── serial
│   └── serial.old
├── intermediate.config
├── intermediate.csr
├── intermediate_ca.ext
├── intermediate_req.config
├── root
│   ├── 00.pem
│   ├── 01.pem
│   ├── database
│   ├── database.attr
│   ├── database.attr.old
│   ├── database.old
│   ├── index
│   ├── serial
│   └── serial.old
├── root.config
├── root.csr
├── root_ca.ext
├── root_req.config
├── server.csr
├── server_leaf.ext
└── server_req.config

2 directories, 42 files
</pre>

Note: each time you generate new keys and certificates, all keys and certificates from the previous
run are deleted.

Here are some examples of how to generate keys:

### Example: no authentication

The default (i.e. if no command-line options are given) is no authentication. In other words, no
no keys or certificates are generated, and the keys and certificates from the previous run are
removed:

<pre>
(venv) $ <b>./create-keys-and-certs.sh</b>
No authentication (no keys or certificates generated)
</pre>

### Example: server-only authentication, self-signed certificates

In the following example, we only generate a key and a certificate for the server. 
The client is not authenticated, so we do not generate a key or certificate for the client.
The server certificate is self-signed, so we don't generate any keys or certificates for certificate
authorities.

<pre>
(venv) $ <b>./create-keys-and-certs.sh --authentication server --signer self</b>
Created server certificate (self-signed)
Created server certificate chain
</pre>

### Example: mutual authentication, certificates signed by an intermediate certificate authority

In the following, we use mutual authentication. The client authenticates the server, so we need
a key and a certificate for the server. And the server also authenticates the client, so we need
a key and a certificate for the client.

Both the server and the client certificate are signed by an intermediate certificate authority (CA).
So, we need a key and a certificate for this intermediate CA.
The certificate of the intermediate CA is signed by a root CA.
So, we need a key and a certificate for this root CA.
The certificate of the root CA is self-signed.

<pre>
(venv) $ <b>./create-keys-and-certs.sh --authentication mutual --signer intermediate</b>
Created root private key
Created root certificate signing request
Created root certificate
Created intermediate private key
Created intermediate certificate signing request
Created intermediate certificate
Created server private key
Created server certificate signing request
Created server certificate
Created server certificate chain
Created client private key
Created client certificate signing request
Created client certificate
Created client certificate chain
</pre>

### Example: select server name and client name

By default the name of the server in the server certificate is `localhost`.
Similarly, by default the name of the client in the client certificate is `localhost`.
This is appropriate when (a) authentication is host-based and (b) the server and the client are
running on the same host.

When authentication is service-based or when the server and client are running on different hosts
you want to explicitly choose the name of the server and the name of the client in the certificates.
You can do this using the `--server-name` and `--client-name` command line options.

<pre>
(venv) $ <b>./create-keys-and-certs.sh --authentication mutual --signer intermediate --server-name alice --client-name bob</b>
Created root private key
Created root certificate signing request
Created root certificate
Created intermediate private key
Created intermediate certificate signing request
Created intermediate certificate
Created server private key
Created server certificate signing request
Created server certificate
Created server certificate chain
Created client private key
Created client certificate signing request
Created client certificate
Created client certificate chain
</pre>

### Example: purposely generating a wrong key

The automated test script (which is described in detail below) does not only do positive test cases
but also negative test cases:
* In a positive test case, we verify that the client can communicate with the server when the
  authentication keys and certificates are correct.
* In a negative test case, we verify that the client cannot communicate with the server when the
  authentication keys and certificates are incorrect. Not being able to communicate is the desired
  behavior in this case.

The `--wrong-key` command-line argument is used to generate a wrong key on purpose to facilitate
negative testing. The following arguments are available:
* `--wrong-key none`: don't generate any wrong keys (the default behavior).
* `--wrong-key client`: generate a wrong key for the client.
* `--wrong-key server`: generate a wrong key for the server.
* `--wrong-key intermediate`: generate a wrong key for the intermediate CA.
* `--wrong-key root`: generate a wrong key for the root CA.

The exact definition of a wrong key is slightly different for leaves (the server and client) versus
CAs (the intermediate CA and root CA):
* Generating a wrong key for a leaf means that the private key does not match the public key in the
  certificate.
* When generating a wrong key for a CA, the CA private key still matches the CA public key in the CA
  certificate. However, the private CA key does not match the private key that was used for signing
  other certificates.

In the following example, we purposely generate a wrong key for the client. Notice that the client
private key is generate twice: one before the certificate is generated and then again after the
certificate is generated. As a result the client private key does not match the public key in the
certificate.

<pre>
(venv) $ <b>./create-keys-and-certs.sh --authentication mutual --signer root --wrong-key client</b>
Created root private key
Created root certificate signing request
Created root certificate
Created server private key
Created server certificate signing request
Created server certificate
Created server certificate chain
<i>Created client private key</i>
Created client certificate signing request
Created client certificate
Created client certificate chain
<i>Created client private key</i>
</pre>




As you can see there are almost endless variations and permutations for authentication, which
brings us to the next topic...


## Automated Testing of Authentication

The `test.sh` bash shell script automates the testing all possible combinations and permutations
of client to server authentication.

The `--help` command-line option describes what it does and what command-line options are available:

<pre>
(venv) $ ./test.sh --help

SYNOPSIS

    test.sh [OPTION]...

DESCRIPTION

  Test authentication between the gRPC client and the gRPC server.

  The following authentication methods are tested: no authentication, server
  authentication (the client authenticates the server, but not vice versa), and mutual
  authentication (the client and the server mutually authenticate each other).

  The following certificate signing methods are tested: self-signed certificates,
  certificates signed by a root CA, and certificates signed by an intermediate CA.

  There are both positive and negative test cases. The positive test cases verify that
  the gRPC client can successfully call the gRPC server when all keys and certificates
  correct. The negative test cases verity that the gRPC client cannot call the gRPC
  when some private key is incorrect, i.e. does not match the public key in the
  certificate.

  The tests are run in two environments: local and docker. The local test runs the server
  and client as local processes on localhost. The docker test runs the server and client
  in separate docker containers, each with a different DNS name.

  The server can identify itself using the DNS name of the host on which it runs, or
  it can use the TLS server name indication (SNI) to identify itself using a service
  name.

  We use two different clients for testing: client.py in this repo and Evans
  (https://github.com/ktr0731/evans)

OPTIONS

  --help, -h, -?
      Print this help and exit

  --skip-evans
      Skip the Evans client test cases.

  --skip-docker
      Skip the docker test cases.

  --skip-negative
      Skip the negative test cases.

  --verbose, -v
      Verbose output; show all executed commands and their output.
</pre>

To run all test cases, simple invoke the `test.sh` script without any parameters:

<pre>
(venv) $ time ./test.sh
Pass: correct_key_test_case: location=local client=python authentication=none signer=none server_naming=host client_naming=host check_client_naming=dont_check
Pass: correct_key_test_case: location=local client=python authentication=server signer=self server_naming=host client_naming=host check_client_naming=dont_check
[... 228 lines cut ...]
Pass: wrong_client_test_case: location=docker client=evans authentication=mutual signer=root
Pass: wrong_client_test_case: location=docker client=evans authentication=mutual signer=intermediate
All 232 test cases passed</pre>

On my 2020 MacBook Air, it takes about 12 minutes to complete the full test suite.

If you don't have Docker of Evans installed on your computer, use the corresponding `--skip-...`
command line option to skip those test cases.





# ** CONTINUE FROM HERE **

# Implementation Details

## Grpcio versus grpclib

In this tutorial we use the official
[Python gRPC AsyncIO API](https://grpc.github.io/grpc/python/grpc_asyncio.html),
also known as "grpcio", which is part of the official
[Python gRPC API](https://grpc.io/docs/languages/python/)
in the official [gRPC implementation](https://grpc.io/).

There is also an older third-party implementation of the Python gRPC AsyncIO API, knows as 
"[grpclib](https://pypi.org/project/grpclib/)"
([GitHub repo](https://github.com/vmagamedov/grpclib)).
We won't be using this library. Many code fragments that show up in Google or StackOverflow search
results are based on grpclib instead of grpcio and won't work with the code in this tutorial. Be
careful!

## Setup

The following steps describe how to setup the environment for following this tutorial.

Clone the `secure-grp` GitHub repository.

```
git clone https://github.com/brunorijsman/secure-grpc.git
```

Create a Python virtual environment and activate it. We use Python3.8 but later versions should work
as well.

```
cd secure-grpc
python3.8 -m venv venv
source venv/bin/activate
```

Install the dependencies:

```
pip install --upgrade pip
pip install -r requirements.txt
```

You will also need `OpenSSL`. I run macOS Catalina 10.15.7 which comes with LibreSSL version 2.8.3
pre-installed:

<pre>
$ <b>which openssl</b>
/usr/bin/openssl
$ <b>openssl version</b>
LibreSSL 2.8.3
</pre>

## The unsecured `Adder` service.

We start with an unsecured gRPC service.
This will help us understand the basics of writing gRPC servers and clients in asynchronous Python
before we introduce the extra complications of authentication and encryption, which we will cover in
later sections.

The repository already contains the gRPC service definition file `adder.proto` which defines a
very simple `Adder` service that can add two numbers.

```protobuf
syntax = "proto3";

package adder;

message AddRequest {
    int32 a = 1;
    int32 b = 2;
}

message AddReply {
    int32 sum = 1;
}

service Adder {
    rpc Add (AddRequest) returns (AddReply);
}
```

Run the protobuf compiler.

```bash
python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. adder.proto 
```

This compiles the gRPC service definition file `adder.proto` and generates two Python module files:

* Python module `adder_pb2.py` defines the protobuf message classes `AddRequest` and `AddReply`.

* Python module `adder_pb2_grpc.py` defines the class `AdderServicer` for the server and the
  class `AdderStub` for the client.

Existing file `server.py` contains the implementation of the server. At this point we
don't have any authentication or encryption yet.

```python
import asyncio
import grpc
import adder_pb2
import adder_pb2_grpc

class Adder(adder_pb2_grpc.AdderServicer):

    async def Add(self, request, context):
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply

async def serve():
    server = grpc.aio.server()
    adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server)
    server.add_insecure_port("127.0.0.1:50051")
    await server.start()
    await server.wait_for_termination()

if __name__ == "__main__":
    asyncio.run(serve())
```

Existing file `client.py` contains the implementation of the unsecured client:

```python
import asyncio
import grpc
import adder_pb2
import adder_pb2_grpc

async def run_client():
    async with grpc.aio.insecure_channel("127.0.0.1:50051") as channel:
        stub = adder_pb2_grpc.AdderStub(channel)
        request = adder_pb2.AddRequest(a=1, b=2)
        reply = await stub.Add(request)
        assert reply.sum == 3
        print(f"Client: {request.a} + {request.b} = {reply.sum}")

if __name__ == "__main__":
    asyncio.run(run_client())
```

In one terminal window, start the server:
```
python server_unsecured.py
```

In another terminal window, run the client:
```
python client_unsecured.py
```

The client produces the following output:
```
Client: 1 + 2 = 3
```

Back in the server terminal window, you should see the following server output:
```
Server: 1 + 2 = 3
```

# Client authenticates server using TLS

We will now update the code to use Transport Layer Security (TLS) to let the client authenticate
the server and to encrypt all traffic between the client and the server.
At this point, the server does not yet authenticate the client, i.e. we don't Mutual TLS
(MTLS) yet.

For now we will be using self-signed certificates. This means we have to manually
install the certificate for each trusted server on the client. In later sections we will describe
how to use Certificate Authorities (CAs) to avoid this manual installation step.

Use the following command to generate both the private key and the self-signed certificate that
contains the corresponding public key:

```
$ openssl req -newkey rsa:2048 -nodes -keyout server.key -x509 -subj "/C=US/ST=WA/L=Seattle/O=RemoteAutonomy/CN=localhost" -out server.crt
Generating a 2048 bit RSA private key
..+++
...................................................................................................................................+++
writing new private key to 'server.key'
-----
```

The meaning of the `openssl` command line options is as follows:
* `req`: Create a certificate request in PKCS#10 format.
* `-newkey rsa:2048`: Create a new certificate request and a new private key, which is a 2048 bit
   RSA key.
* `-nodes`: Do not encrypt the private key file.
* `-keyout server.key`: Create a private key file `server.key`.
* `-x509`: Issue a self-signed certificate instead of a certificate request.
* `-subj "/C=US/ST=WA/L=Seattle/O=RemoteAutonomy/CN=localhost"`: Sets the subject in the certificate.
   `C` is the country, `ST` is the state, `L` is the locality, `O` is the organization, and `CN`
   is the common name.
* `-out server.crt`: Create a certificate file `server.crt`.

The `server.key` file contains text similar to the following (your key will be different):

```
 $ cat server.key
-----BEGIN RSA PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDRqQxWhgEDgZ1M
2nsyOh3gqsLUa4m3SPhrk1zSo3g7p4JkRHSSKVTI2NQOomMyFc6SobvoRJ0QGIYF
[...]
YxsfPh3BSJUts81T0X/0NGuVR+wyO7BlL1yTlLB9ysoBTFiYMuE8xasx5LOixWjh
ojBvoD5gGqC5UiAz9aKETA==
-----END RSA PRIVATE KEY-----
```

This gibberish is the @@@

You can look at the decoded contents of the private key file using the following command:

```
$ openssl rsa -noout -text -in server.key
Private-Key: (4096 bit)
modulus:
    00:c5:1b:cf:10:1f:87:bc:3f:2e:38:97:79:0c:3e:
    e7:6d:41:e8:e5:e8:71:77:57:5b:a9:07:d7:03:3e:
    [...]
    08:49:a1:62:c2:87:81:8f:a2:2e:9b:1c:45:2a:72:
    96:1d:69
publicExponent: 65537 (0x10001)
privateExponent:
    6f:57:52:13:ed:7b:a3:1e:9d:61:62:4f:02:57:d6:
    2a:a5:7c:85:c2:53:b5:f2:26:d8:c8:90:f0:48:0c:
    [...]
    45:cc:59:8a:98:ec:39:86:8f:e2:0c:eb:38:86:99:
    cb:31
prime1:
    00:f9:f9:16:2e:c9:ab:23:7c:c9:e1:a5:b4:df:f7:
    0c:6d:d7:b0:d2:40:4c:2c:f4:ab:de:08:d2:a6:cb:
    [...]
    f1:86:dc:a9:46:80:c2:ce:01:6d:64:41:ba:66:cb:
    46:0f
prime2:
    00:c9:dc:6d:28:36:e8:9a:5a:a5:aa:ed:89:6c:a0:
    c0:34:92:91:5c:78:e1:c7:9d:46:9b:05:61:08:e2:
    [...]
    61:8b:a2:12:27:de:1f:d1:c2:a0:10:0c:79:05:f0:
    9d:07
exponent1:
    00:bb:b5:a5:47:bb:1e:ad:46:5e:de:f8:2d:2b:e5:
    7b:4a:dc:a6:26:2c:2c:47:b1:ef:81:8b:04:8c:45:
    [...]
    ae:99:04:08:85:2d:d9:9b:12:8d:4f:b4:df:c1:a3:
    31:57
exponent2:
    05:a5:55:a4:3f:4c:e8:2c:4a:df:e9:fe:e2:fb:e8:
    04:50:69:22:65:fb:22:a3:22:7b:69:7e:1a:4a:85:
    [...]
    4f:82:7b:f1:83:83:ee:50:fc:3b:16:ae:37:dd:4f:
    f7
coefficient:
    00:d0:b9:35:35:ee:a7:4e:58:50:bd:4e:55:10:58:
    fd:4d:de:e4:e8:b3:70:7a:48:d2:8d:a5:10:91:d4:
    [...]
    30:0f:43:17:e8:6f:9f:8b:a1:36:86:73:7e:2b:21:
    03:5f
```

As you can see, the private key file does not actually contain the private key itself. Instead, it
contains a number of parameters (modulus, public exponent, private exponent, prime 1, prime 2,
exponent 1, exponent 2, and coefficient) from which you can compute both the private key and the
public key using the [RSA algorithm](https://en.wikipedia.org/wiki/RSA_(cryptosystem)).

Similarly, the certificate file contains ASN.1 encoded gibberish:

```
(venv) $ cat server.crt
-----BEGIN CERTIFICATE-----
MIIDKDCCAhACCQCrGNDUOW0JjjANBgkqhkiG9w0BAQsFADBWMQswCQYDVQQGEwJV
UzELMAkGA1UECAwCV0ExEDAOBgNVBAcMB1NlYXR0bGUxFzAVBgNVBAoMDlJlbW90
[...]
LSk0YNPiS+kvhGgc3jCLblFASgbBK2/oasdfMJ/v29vmItXhPibciTmeSM7kPcC6
WMXyk6u6L4Ee0tI7xgQfczcZkaKawGqFKcbY/H+PqbJG/0fCkGG/npbUcYI=
-----END CERTIFICATE-----
```

Use the following command to see the decoded certificate:

```
(venv) $ openssl x509 -in server.crt -text -noout
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 12328833589841824142 (0xab18d0d4396d098e)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, ST=WA, L=Seattle, O=RemoteAutonomy, CN=server
        Validity
            Not Before: May 12 09:38:56 2021 GMT
            Not After : Jun 11 09:38:56 2021 GMT
        Subject: C=US, ST=WA, L=Seattle, O=RemoteAutonomy, CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d1:a9:0c:56:86:01:03:81:9d:4c:da:7b:32:3a:
                    1d:e0:aa:c2:d4:6b:89:b7:48:f8:6b:93:5c:d2:a3:
                    [...]
                    58:d9:7f:39:dd:fb:af:a3:b7:1b:6e:63:e0:7a:18:
                    04:af
                Exponent: 65537 (0x10001)
    Signature Algorithm: sha256WithRSAEncryption
         87:e9:fa:39:32:6c:3c:b6:1e:7b:88:82:bf:c2:2f:d7:02:33:
         a1:43:98:5c:c0:65:b4:0c:72:dc:1b:71:ca:dd:9e:13:a1:26:
         [...]
         6a:85:29:c6:d8:fc:7f:8f:a9:b2:46:ff:47:c2:90:61:bf:9e:
         96:d4:71:82
```

A few things to notice:

* The `Issuer` and the `Subject` field are the same. This makes it a self-signed certificate.

* The certificate is signed by the issuer (once again, self-signed). We can use the public key of
  the issuer (which is in the certificate itself) to verify that the signature is authentic.

* Technically, the certificate does not actually contain the public key; instead it contains the
  parameters (modulus and exponent) that allow the public key (but not the private key) to be
  computed using the RSA algorithm.


# Additional Reading

* [gRPC Authentication Guide](https://grpc.io/docs/guides/auth/)

* [gRPC Python Documentation](https://grpc.github.io/grpc/python/index.html)

* [gRPC Python AsyncIO ("grpcio") Documentation](https://grpc.github.io/grpc/python/grpc_asyncio.html)

* [gRPC ALTS Documentation](https://grpc.io/docs/languages/python/alts/)

* [Google ALTS Whitepaper](https://cloud.google.com/security/encryption-in-transit/application-layer-transport-security)

* [grpclib Homepage](https://pypi.org/project/grpclib/) [Note]

* [grpclib GitHub Page](https://github.com/vmagamedov/grpclib) [Note]
