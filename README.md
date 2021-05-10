# Securing Google Remote Procedure Calls (gRPC)

## Introduction

This is a step-by-step tutorial on how to secure Google Remote Procedure Calls (gRPC) using
asynchronous Python (asyncio).

1. Start with an unsecured service (no authentication and no encryption).

2. TODO Add encryption and client authentication of the server (manual installation of the server
   certificate at the client).

3. TODO Use a certificate authority (CA) instead of manual installation of certificates.

4. TODO Mutual authentication: the server also authenticates the server.

## TLS versus mTLS versus ALTS

TODO

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

Existing file `server_unsecured.py` contains the implementation of the server. At this point we
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

Existing file `client_unsafe.py` contains the implementation of the unsecured client:

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

We will now update the code, on both the server and client code, to use Transport Layer Security
(TLS) to let the client authenticate the server and to encrypt all traffic between the client and
the server.

At this point, the server does not yet authenticate the client, i.e. we do not yet have Mutual TLS
(MTLS).

Also, at this point we will be using self-signed certificates. This means we have to manually
install the certificate for each trusted server on the client. In later sections we will describe
how to use Certificate Authorities (CAs) to avoid this manual installation step.

TODO: Generate certificate and private key on server

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