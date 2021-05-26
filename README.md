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
the parameters listed below. The test scrips tests all possible parameter combinations.

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

## Server Name Indication (SNI)

When the client authenticates the server, it can perform the **server naming check** in one of two
ways:

* The client verifies that the server name in the certificate matches the DNS host name of the
  server. This default behavior of TLS. We refer to this as **server host naming** in our code.

* The client uses the TLS Server Name Indication (SNI) option to explicitly choose the server name
  to be authenticated. Historically, this was typically used when multiple different web sites where
  hosted on a single web servers. The web server used the SNI option to present the correct
  certificate to the client. In the context of APIs, it allows us to decouple the naming of services
  from hosts. Hence, we refer to this as **server service naming** in our code.

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

* **TLS**: Transport Layer Security. It provides both authentication and encryption. By default
  only the client authenticates the server (and not vice versa).

* **mTLS**: Mutual Transport Layer Security. The same as TLS, except that the client and server
  mutually authenticate each other. It is not really a different protocol; just a specific way of
  using TLS.

* **ALTS**: Application Layer Transport Protocol. This is a new protocol defined by Google that
  is more optimized for authentication and encryption in the context of application-to-application
  API calls (as opposed to TLS which has its historical roots in web browser to web server
  security).

* GRPC also supports **token-based authentication** which is intended to be used in Google APIs
  (e.g. APIs in Google Cloud Platform).

We currently only support TLS and mTLS version 1.3. We do not yet support ALTS or tokens.

# ** CONTINUE FROM HERE **

## TLS versus mTLS versus ALTS

In this tutorial we look at three different [authentication protocols](https://grpc.io/docs/guides/auth/):

1. [Transport Layer Security (TLS)](https://datatracker.ietf.org/doc/html/rfc8446),
   also known by its former and deprecated name Secure Sockets Layer (SSL). 
   This is a widely used standard protocol for providing authentication and encryption
   at the transport (TCP) layer. It is the underlying protocol for secure application layer
   protocols such as HTTPS. In many use cases (e.g. secure web browsing) TLS is only used for the
   client to authenticate the server and for encryption. In such cases, some other mechanism (e.g.
   a username and a password or a two-factor authentication hardware token) is used for the server
   to authenticate the client.

2. Mutual TLS (MTLS). When TLS is used for application-to-application communications (as opposed
   to human-to-application communications) it is common to use TLS for both parties to authenticate
   each other. Not only does the client authenticate the server, but the server also authenticates
   the client.

3. [Application Layer Transport Security (ALTS)](https://cloud.google.com/security/encryption-in-transit/application-layer-transport-security) 
   is a mutual authentication and transport encryption system developed by Google and typically used
   for securing Remote Procedure Call (RPC) communications within Google's infrastructure. ALTS 
   is similar in concept to MTLS but has been designed and optimized to meet the needs of Google's
   datacenter environments.

GRPC also supports a token-based authentication protocol which we will not discuss in this tutorial.
It is intended for interacting with Google APIs provided by the Google Cloud Platform (GCP).

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




TODO: Install server certificate on client

TODO: 127.0.0.1 vs hostname etc (two different virtual machines)

TODO: Diagram explaining certificates

TODO: Update client code load certificate

TODO: Update server code to update server certificate and private key


# Documentation references

* [gRPC Authentication Guide](https://grpc.io/docs/guides/auth/)

* [gRPC Python Documentation](https://grpc.github.io/grpc/python/index.html)

* [gRPC Python AsyncIO ("grpcio") Documentation](https://grpc.github.io/grpc/python/grpc_asyncio.html)

* [gRPC ALTS Documentation](https://grpc.io/docs/languages/python/alts/)

* [Google ALTS Whitepaper](https://cloud.google.com/security/encryption-in-transit/application-layer-transport-security)

* [grpclib Homepage](https://pypi.org/project/grpclib/) [Note]

* [grpclib GitHub Page](https://github.com/vmagamedov/grpclib) [Note]

Note: This tutorial uses grpcio; it does not use grpclib.
