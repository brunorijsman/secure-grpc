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

As you can see there are almost endless variations for authentication.
For this reason we have an automated test script (which is described later) to automate trying
all possible combinations.

## Using Docker

So far we have run the server and the client locally from our bash shell. In this scenario, both the
server and the client use `localhost` as the DNS host name.

To test other host names we run the server and the client in different Docker containers and connect
the two containers using a Docker network.

We have created some convenience bash shell scripts to make starting and stopping these containers
easier.

The `docker/docker-build.sh` script builds the Docker image. 

<pre>
(venv) $ <b>docker/docker-build.sh</b>
Sending build context to Docker daemon  10.24kB
Step 1/11 : FROM ubuntu:20.04
 ---> 7e0aa2d69a15
Step 2/11 : RUN apt-get update -y
 ---> Using cache
 ---> 2aad84ffaf70
Step 3/11 : RUN apt-get install -y python3
 ---> Using cache
 ---> 92d2bca80ac8
Step 4/11 : RUN apt-get install -y python3-pip
 ---> Using cache
 ---> 0b7733fd6768
Step 5/11 : RUN apt-get install -y net-tools
 ---> Using cache
 ---> 827ca4a7fd94
Step 6/11 : RUN apt-get install -y wget
 ---> Using cache
 ---> 81efc9d4bb38
Step 7/11 : COPY requirements.txt requirements.txt
 ---> Using cache
 ---> 4cc74fc4b6f3
Step 8/11 : RUN pip3 install -r requirements.txt
 ---> Using cache
 ---> a6c713091119
Step 9/11 : RUN wget https://github.com/ktr0731/evans/releases/download/0.9.3/evans_linux_amd64.tar.gz
 ---> Using cache
 ---> 9022f0e45772
Step 10/11 : RUN tar xvf evans_linux_amd64.tar.gz
 ---> Using cache
 ---> 3dc5f33f2db5
Step 11/11 : VOLUME /host
 ---> Using cache
 ---> 4a8666ff31f1
Successfully built 4a8666ff31f1
Successfully tagged secure-grpc:latest
</pre>

Note that we do not package the client or server Python code nor the generated keys and
certificates into the Docker image. 
Instead, the Docker image mounts a directory in the container to the host file system.
This way, we don't have to rebuild the Docker image each time we change the code or each time we
generate new keys and certificates.

The `docker/docker-server.sh` script starts the server in a Docker container. 
The host name of this Docker container is `adder-server-host`. 
The script also creates a Docker network named `secure-grpc-net` and assigns IP address
`172.30.0.2/16` to the server.
Here we start the server in the background so that we can start the client in the same terminal
window.

<pre>
(venv) $ <b>docker/docker-server.sh</b> &
[1] 31244
</pre>

The `docker\docker-client.sh` script starts the client in a Docker container.
The host name of this Docker container is `adder-client-host`. 
The script attaches the client to the `secure-grpc-net` Docker network and assigns IP address
`172.30.0.3/16` to the client.

<pre>
(venv) $ docker/docker-client.sh
Client: No authentication
Client: connect to adder-server-host:50051
Client: 5052 + 2161 = 7213
</pre>

The `docker\docker-cleanup.sh` script cleans up any Docker containers and Docker networks left
behind by previous runs.

<pre>
(venv) $ ./docker/docker-cleanup.sh
</pre>

## Automated Testing of Authentication

The `test.sh` bash shell script automates the testing all possible combinations of client to server
authentication.

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

On my 2020 MacBook Air, it takes about 9 minutes to complete the full test suite.

If you don't have Docker of Evans installed on your computer, use the corresponding `--skip-...`
command line option to skip those test cases.

# Implementation Details

## Asynchronous Python

The server and the client are written in Python. It has been tested using Python 3.8. The code is
asynchronous, i.e. it uses the `async` and `await` keywords. The scripts to generate keys and
certificates and the test script are written as `bash` shell scripts.

In this tutorial we use the official
[Python gRPC AsyncIO API](https://grpc.github.io/grpc/python/grpc_asyncio.html),
also known as "grpcio", which is part of the official
[Python gRPC API](https://grpc.io/docs/languages/python/)
in the official [gRPC implementation](https://grpc.io/).

There is also an older third-party implementation of the Python gRPC AsyncIO API, knows as 
"[grpclib](https://pypi.org/project/grpclib/)"
([GitHub repo](https://github.com/vmagamedov/grpclib)).
We have not used this library. Many code fragments that show up in Google or StackOverflow search
results are based on grpclib instead of grpcio and won't work with the code in this tutorial. Be
careful!

Most of the concepts in this article are language independent, and the Python code should be easy
to port to other gRPC language bindings.

## The Service Definition

Our example server offers a very simple `Adder` service that can only add two numbers and return
the sum. 
It is defined in file `adder.proto`:

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

The bash script `compile-proto.sh` compiles the gRPC service definition file `adder.proto` and 
generates two Python module files:

* Python module `adder_pb2.py` defines the protobuf message classes `AddRequest` and `AddReply`.

* Python module `adder_pb2_grpc.py` defines the class `AdderServicer` for the server and the
  class `AdderStub` for the client.

The generated files have already been checked in to the git repository, so there is no need to run
the `compile-proto.sh` script unless you change the `adder.proto` file.

## Server Implementation

The Python script `server.py` contains the implementation of the server.
Although the script is not very long, we only highlight some of the most important code fragments
here.

First, we create a gRPC AIO server:

```python
server = grpc.aio.server()
```

We need to add a port to the server to listen for incoming connections.
We need to assign an host name or host address and a TCP port to that port.
Here we use some hard-coded values for the sake of example (in the real code it is configurable
using command-line arguments)

```python
server_address = "adder-server-host:50051"
```

If we are not doing authentication, we need to add an insecure port:

```python
server.add_insecure_port(server_address)
```

If we are doing authentication, we need to create some credentials (this is explained below) and
add a secure port.

```python
credentials = make_credentials() # Function make_credentials for the server is below.
server.add_secure_port(server_address, credentials)
```

Once a port is added, we call function `adder_pb2_grpc.add_AdderServicer_to_server` to register
the class that will service the incoming requests from clients.
Recall that module `adder_pb2_grpc` was generated by the gRPC compiler from the `adder.proto`
model file. Class `Adder` is explained below.

```python
adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server) # Class Adder is below.
```
Finally, we start the server:

```python
await server.start()
```
Now, let's return to generating the credentials.

We are doing server authentication (as opposed to mutual authentication) then the credentials 
consist only of the server's private key and the server's certificate chain.

If the server's certificate is self-signed, then the certificate chain contains only the server's
self-signed certificate.
If the server's certificate is CA-signed, then the certificate chain contains the entire certificate
chain, starting at the server's certificate and going up to the root-CA certificate, with all the
intermediate-CA certificates in between.
The code is the same for self-signed and CA-signed certificates: just load the certificate chain.

```python
def make_credentials():
    server_private_key = open("keys/server.key", "br").read()
    server_certificate_chain = open("certs/server.pem", "br").read()
    private_key_certificate_chain_pairs = [(server_private_key, server_certificate_chain)]
    credentials = grpc.ssl_server_credentials(private_key_certificate_chain_pairs)
    return credentials
```

When we are doing mutual authentication, i.e. when the server also authenticates the client (in
addition to the client authenticating the server) we have to also provide the root certificate to
authenticate the client and we have to set the `require_client_auth` flag to `True`.

```python
def make_credentials():
    server_private_key = open("keys/server.key", "br").read()
    server_certificate_chain = open("certs/server.pem", "br").read()
    private_key_certificate_chain_pairs = [(server_private_key, server_certificate_chain)]
    root_certificate_for_client = open("certs/root.crt", "br").read()
    credentials = grpc.ssl_server_credentials(private_key_certificate_chain_pairs,
                                              root_certificate_for_client, True)
    return credentials

```

In the above code fragment, we assumed that the client certificate was CA-signed. If the client
certificate is self-signed we have to use the client certificate as the root certificate:

```python
root_certificate_for_client = open("certs/client.crt", "br").read()
```

The final step is to define the `Adder` class which actually processes the incoming requests from
clients. It is very simple. Recall that the `adder_pb2_grpc` module was generated by the gRPC
compiler.

```python
class Adder(adder_pb2_grpc.AdderServicer):

    async def Add(self, request, context):
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply
```

If mutual authentication is enabled as described earlier, the server will validate the client in the
sense that it will check that the certificate that was received is properly signed using a signature
that can be traced back to the trusted root.

However, by default, the server does not perform any authentication check on the client name that
is stored in the common name or the subject alternative information in the certificate.
Any client is allowed as long as it has a valid certificate, regardless of the client name.

If we wish to authenticate clients by name, we have to write explicit code for that in the
`Adder` class. In the following example, we only allowed clients that identify themselves as
`adder-client` in the certificate.

```python
class Adder(adder_pb2_grpc.AdderServicer):

    async def validate_client(self, context):
        encoded_allowed_client_name = "adder-client".encode()
        if encoded_allowed_client_name == context.auth_context()["x509_common_name"]:
            return
        if encoded_allowed_client_name in context.peer_identities():
            return
        await context.abort(grpc.StatusCode.PERMISSION_DENIED, "Unauthorized client")

    async def Add(self, request, context):
        await self.validate_client(context)
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply
```

## Client Implementation

The Python script `client.py` contains the implementation of the client.
Once again, we only highlight some of the most important code fragments here.

First, we have to create a gRPC channel to the server.

Here we hard-code the hostname and TCP port number of the server:

```
server_address = "adder-server-host:50051"
```

If we are not doing authentication, we create an insecure channel.

```python
channel = grpc.aio.insecure_channel(server_address)
```

If we are doing authentication (i.e. if the client does authenticate the server), we create
some credentials (this is explained below) and use them to create a secure channel.

```python
credentials = make_credentials() # Function make_credentials for the client is below.
channel = grpc.aio.secure_channel(server_address, credentials)
```
By default, the client will not only authenticate that a properly signed certificate is received
from the server, but also that the name of the server (as stored in the common name or subject
alternative name in the certificate) matches the host name of the server (`adder-server-host`
in this example).

Sometimes that is not what we want. Sometimes we want to use a different name to authenticate the
server than the host name of the host on which the server is running. A typical scenario is when
there are multiple servers running on a single host. We can use the server name indication (SNI)
option to specify the name that we want to use to authenticate the server. This name has to match
the name that is stored in the server certificate. In the following example, we use a hard-coded
name `adder-server-service` as the validated name.

```python
credentials = make_credentials() # Function make_credentials for the client is below.
options = (("grpc.ssl_target_name_override", "adder-server-service"),)
channel = grpc.aio.secure_channel(server_address, credentials, options)
```

Now, let's return to generating client-side credentials.

If we are only doing server authentication (as opposed to mutual authentication) then we only have
to provide the certificate of the root-CA that will be used to validate the certificate received
from the server:

```python
def make_credentials():
    root_certificate_for_server = open("certs/root.crt", "br").read()
    credentials = grpc.ssl_channel_credentials(root_certificate_for_server)
    return credentials
```

If the root certificate is self-signed, then we use the server certificate as the root certificate:

```python
root_certificate_for_server = open("certs/server.crt", "br").read()
```

If we are doing mutual authentication, i.e. if the server also authenticates the client, then we
also have to provide the client private key and the client certificate chain:

```python
def make_credentials():
    root_certificate_for_server = open("certs/root.crt", "br").read()
    client_private_key = open("keys/client.key", "br").read()
    client_certificate_chain = open("certs/client.pem", "br").read()
    credentials = grpc.ssl_channel_credentials(root_certificate_for_server, client_private_key,
                                               client_certificate_chain)
    return credentials
```

Once we have a channel with its associated credentials, we create a stub.
Recall that the `adder_pb2_grpc` module was generated by the gRPC compiler from the `adder.proto`
model file.

```python
stub = adder_pb2_grpc.AdderStub(channel)
```

We can use the stub to invoke a server gRPC call and wait for the result:

```python
a = random.randint(1, 10001)
b = random.randint(1, 10001)
request = adder_pb2.AddRequest(a=a, b=b)
try:
    reply = await stub.Add(request)
except grpc.RpcError as rpc_error:
    print(f"Client: server returned error {rpc_error}")
    sys.exit(1)
print(f"Client: {request.a} + {request.b} = {reply.sum}")
```

In our example, we close the channel and exit after making one call:

```python
await channel.close()
```

## Key and Certificate Generation Implementation

The `create-keys-and-certs.sh` hides all of the complexity of generating keys and certificates
using the `openssl` tool chain.
The theory of generating keys and certificates is not very complex, but the `openssl` tool chain
is quite temperamental and difficult to use.

### Generating a private key

We need to produce private keys for the leaves (the server and the client) and for the certificate
authorities (the root CA and the intermediate CA). In this example we will be producing a private
for the client.

The following command generates a 2048 bit RSA key and stores it in file `client.key`.

<pre>
$ <b>openssl genrsa -out keys/client.key 2048</b>
Generating RSA private key, 2048 bit long modulus
.....+++
..............................................................................................+++
e is 65537 (0x10001)
</pre>

File `client.key` is typically referred to as a private key file.
In reality is doesn't contain the private key per-se, but a set of parameters from which both
the private and the public key can be generated.

The private key file is secret, must be stored in a secure location that is only accessible to the
owner of the private key. For example, the client private key must be stored in a location where
only the client has access.

The contents of the `client.key` file look like gibberish; not because it is encrypted but rather
because it is encoded using the ASN.1 encoding rules and a base-64 representation:

```
$ <b>cat keys/client.key</b>
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA0zptDHxc3MiD/Bpa24ike+xcaBQr1BjSDOEwPOkILtBJRudk
avac0uwfWbYn2DILccYirmt2uLtvyFEmNtk7JVb5rte8lsVO0qNAW+i4jsafk7rd
[...]
AA6ye3CdLoc5EDdGK9y3CDTtt2w+3ulZp+jnJN89MmsJ0d06bWTfZTcHVFt2bVFi
jKesxM94ejX2SFd44Sv7prv9qTO/94NmCfRi7HTtrFrTUZ0qK1rEuXM=
-----END RSA PRIVATE KEY-----
```

You can convert the private key file into a human-readable form using the following command.

<pre>
$ <b>openssl rsa -noout -text -in keys/client.key</b>
Private-Key: (2048 bit)
modulus:
    00:d3:3a:6d:0c:7c:5c:dc:c8:83:fc:1a:5a:db:88:
    [...]
    d1:1b:a3:26:b6:0c:63:da:a9:7a:a9:cd:7f:0e:69:
    7b:4d
publicExponent: 65537 (0x10001)
privateExponent:
    51:f1:48:7c:9f:82:26:e4:62:cf:5a:2a:05:20:6d:
    [...]
    79:dc:c7:45:dc:4d:47:3a:55:3a:ee:20:0e:13:c4:
    01
prime1:
    00:f7:9f:bb:f1:b2:65:b7:c7:a3:3b:d4:5b:f3:fc:
    [...]
    d6:97:15:32:53:05:48:2f:b1
prime2:
    00:da:5f:87:25:ed:52:3b:4e:b0:7e:ca:b4:4e:f5:
    [...]
    8b:3b:54:c6:13:bf:24:a8:5d
exponent1:
    00:9e:4e:86:6f:2c:a8:0e:e8:18:99:65:58:2c:11:
    [...]
    a7:49:0b:8a:12:bd:6b:ba:e1
exponent2:
    00:c8:b9:26:30:e6:83:bf:a0:04:fb:86:b7:56:1c:
    [...]
    09:a6:ef:b5:62:51:40:10:c1
coefficient:
    00:b7:f8:44:40:f5:45:de:6e:af:78:01:91:9a:d5:
    [...]
    d3:51:9d:2a:2b:5a:c4:b9:73
</pre>

### Generating a certificate signing request (CSR)

To create a certificate we must first generate a certificate signing request (CSR).
The CSR contains all the information that we want to be in the certificate.
The CSR is given to the certificate authority (CA).
The CA validates that the information in the CSR is correct and truthful, and if so, the CA
generates a certificate with the information from the CSR and signs it with the CA private key.
The CA then gives the generated certificate back to the requesting party.

To generate a CSR with OpenSSL we first prepare a request configuration file that looks similar to
this (in this example we are generating a CSR for the client):

File `admin/client_req.config`:
<pre>
[req]
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[req_distinguished_name]
countryName            = US
stateOrProvinceName    = WA
organizationName       = Example Corp
organizationalUnitName = Engineering
commonName             = adder-client-host

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = adder-client-host
</pre>

Then we use the following OpenSSL command to actually generate the CSR file:

<pre>
$ <b>openssl req \
  -new \
  -text \
  -key keys/client.key \
  -out admin/client.csr \
  -config admin/client_req.config \
  -extensions req_ext</b>
</pre>

This generates a CSR file similar to the following.
Note that the CSR file contains the information in both encoded and decoded form (this is because
of the `-text` option):

<pre>
$ <b>cat admin/client.csr</b>
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject: C=US, ST=WA, O=Example Corp, OU=Engineering, CN=adder-client-host
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c1:97:3d:c7:43:7f:b0:f6:aa:48:e8:16:7e:83:
                    c2:fe:de:c8:cb:24:8f:1e:2d:c0:b0:c1:07:d1:46:
                    [...]
                    51:a5:ba:ae:c7:61:94:81:c1:5f:9e:9a:e9:71:70:
                    e2:81
                Exponent: 65537 (0x10001)
        Attributes:
        Requested Extensions:
            X509v3 Subject Alternative Name:
                DNS:adder-client-host
    Signature Algorithm: sha256WithRSAEncryption
         7e:a2:f3:1a:e7:7b:9c:f7:66:42:91:17:53:83:d5:83:7f:54:
         0a:87:af:06:bc:dd:7c:e5:4d:d9:11:21:7e:e9:30:32:0c:ff:
         [...]
         94:06:55:24:1a:d0:ab:57:8b:20:db:80:49:b7:50:00:f0:75:
         59:bb:7b:1a
-----BEGIN CERTIFICATE REQUEST-----
MIIC1zCCAb8CAQAwYzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAldBMRUwEwYDVQQK
DAxFeGFtcGxlIENvcnAxFDASBgNVBAsMC0VuZ2luZWVyaW5nMRowGAYDVQQDDBFh
[...]
4HxWGju72nZcm/KExahtjaJUkkMl+S51KKqYUOIduPCk7RVdpJQGVSQa0KtXiyDb
gEm3UADwdVm7exo=
-----END CERTIFICATE REQUEST-----
</pre>

# CONTINUE FROM HERE

### Generating a self-signed leaf certificate

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
