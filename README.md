# Securing Google Remote Procedure Calls (GRPC)

This is a tutorial on how to secure Google Remote Procedure Calls (GRPC) using Transport Layer
Security (TLS).

We will be using Python, but the same principles apply to any other programming language.

## Step 1: A simple GRPC service

We are going to secure a very simple GRPC `adder` service that can add two numbers:

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
