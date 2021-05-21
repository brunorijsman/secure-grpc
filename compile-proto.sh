#!/bin/bash

# Copyright 2021 Bruno Rijsman
# Apache License Version 2.0; see LICENSE for details

python -m grpc_tools.protoc --proto_path=. --grpc_python_out=. --python_out=. adder.proto
