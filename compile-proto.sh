#!/bin/bash

python -m grpc_tools.protoc --proto_path=. --grpc_python_out=. --python_out=. adder.proto
