# Securing Google Remote Procedure Calls (gRPC)

This is a step-by-step tutorial on how to secure Google Remote Procedure Calls (gRPC) using
asynchronous Python (asyncio).

1. Start with an unsecured service (no authentication and no encryption).

2. TODO Add encryption and client authentication of the server (manual installation of the server
   certificate at the client).

3. TODO Use a certificate authority (CA) instead of manual installation of certificates.

4. TODO Mutual authentication: the server also authenticates the server.

We use the official [Python gRPC AsyncIO API](https://grpc.github.io/grpc/python/grpc_asyncio.html),
also known as "grpcio", which is part of the official
[Python gRPC API](https://grpc.io/docs/languages/python/)
in the official [gRPC implementation](https://grpc.io/).

There is also an older third-party implementation of the Python gRPC AsyncIO API, knows as 
"[grpclib](https://pypi.org/project/grpclib/)" ([GitHub repo](https://github.com/vmagamedov/grpclib)).
We won't be using this library. Many code fragments that show up in Google or StackOverflow search
results are based on grpclib instead of grpcio and won't work with the code in this tutoral. Be
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
before we add the extra complications of authentication and encryption, which we will cover in later
sections.

The repository already contains the `adder.proto` which defines a very simple GRPC `Adder` service
that can add two numbers.

```protobuf
syntax = "proto3";

package adder;

message AddRequest {
    int32 a = 1;
    int32 b = 2;
}

message AddReply {
    int32 sum = 1;
    bool overflow = 2;
}

service Adder {
    rpc Add (AddRequest) returns (AddReply);
}
```

Run the protobuf compiler.

```bash
python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. adder.proto 
```

This compiles the protobuf file `adder.proto` and produces two Python module files:

* Python module `adder_pb2.py` defines the protobuf message classes `AddRequest` and `AddReply`.

* Python module `adder_pb2_grpc.py` defines the base class `AdderServicer` for the server and the
  class `AdderStub` for the client.

File `server_unsecured.py` contains the unsecured (i.e. without authentication or encryption) server
code:

```python
```

File `client_unsafe.py` contains the unsecured client code:

```python
```



