#!/usr/bin/env python

import argparse
import asyncio
import random
import grpc
import adder_pb2
import adder_pb2_grpc

def parse_command_line_arguments():
    parser = argparse.ArgumentParser(description="Secure gRPC demo client")
    parser.add_argument(
        "authentication",
        choices=["none", "tls"],
        default="none",
        help="Authentication mechanism")
    return parser.parse_args()

async def add_two_numbers(channel):
    stub = adder_pb2_grpc.AdderStub(channel)
    a = random.randint(1, 10001)
    b = random.randint(1, 10001)
    request = adder_pb2.AddRequest(a=a, b=b)
    reply = await stub.Add(request)
    assert reply.sum == a + b
    print(f"Client: {request.a} + {request.b} = {reply.sum}")

async def client_insecure():
    async with grpc.aio.insecure_channel("localhost:50051") as channel:
        await add_two_numbers(channel)

async def client_tls():
    certificate = open("server.crt", "br").read()
    credentials = grpc.ssl_channel_credentials(certificate)
    async with grpc.aio.secure_channel("localhost:50051", credentials) as channel:
        await add_two_numbers(channel)

if __name__ == "__main__":
    args = parse_command_line_arguments()
    if args.authentication == "none":
        asyncio.run(client_insecure())
    elif args.authentication == "tls":
        asyncio.run(client_tls())
    else:
        assert False
