# Securing Google Remote Procedure Calls (GRPC)

TODO: This is for asyncio

This is a tutorial on how to secure Google Remote Procedure Calls (GRPC) using Transport Layer
Security (TLS).

We will be using Python, but the same principles apply to any other programming language.

## Getting setup

The following step describe how to setup the environment for following this tutorial.

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

## A simple GRPC `adder` service

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
python -m grpc_tools.protoc --proto_path=. --python_out=. --grpclib_python_out=. adder.proto 
```

This compiles the protobuf file `adder.proto` and produces two Python module files:

* Python module `adder_pb2.py` defines the protobuf message classes `AddRequest` and `AddReply`.

* Python module `adder_grpc.py` defines the base class `AdderBase` for the server and the base class
  `AdderStub` for the client.

File `server_unsafe.py` contains the unsafe (i.e. without authentication or encryption) server code:

```python
TODO
```

File `client_unsafe.py` contains the unsafe server code:

```python
TODO
```



