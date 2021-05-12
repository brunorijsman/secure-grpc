#!/usr/bin/env python

import asyncio
import random
import grpc
import adder_pb2
import adder_pb2_grpc
import common

async def main():
    args = common.parse_command_line_arguments("server")
    server_address = f"{args.server_host}:{args.server_port}"
    if args.server_authenticated:
        print("Server is authenticated by client")
        server_certificate = open("server.crt", "br").read()
        server_credentials = grpc.ssl_channel_credentials(server_certificate)
        channel = grpc.aio.secure_channel(server_address, server_credentials)
    else:
        print("Server is not authenticated by client")
        channel = grpc.aio.insecure_channel(server_address)
    stub = adder_pb2_grpc.AdderStub(channel)
    print(f"Using server on {server_address}")
    a = random.randint(1, 10001)
    b = random.randint(1, 10001)
    request = adder_pb2.AddRequest(a=a, b=b)
    reply = await stub.Add(request)
    assert reply.sum == a + b
    print(f"Client: {request.a} + {request.b} = {reply.sum}")
    await channel.close()

if __name__ == "__main__":
    asyncio.run(main())
