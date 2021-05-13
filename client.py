#!/usr/bin/env python

import asyncio
import random
import grpc
import adder_pb2
import adder_pb2_grpc
from common import parse_command_line_arguments

async def main():
    args = parse_command_line_arguments("server")
    server_address = f"{args.server_host}:{args.server_port}"
    if args.authentication == "none":
        print("No authentication")
        channel = grpc.aio.insecure_channel(server_address)
    elif args.authentication == "server":
        print("Server authentication")
        server_certificate = open("server.crt", "br").read()
        credentials = grpc.ssl_channel_credentials(server_certificate)
        channel = grpc.aio.secure_channel(server_address, credentials)
    elif args.authentication == "mutual":
        print("Mutual authentication")
        server_certificate = open("server.crt", "br").read()
        client_private_key = open("client.key", "br").read()
        client_certificate = open("client.crt", "br").read()
        credentials = grpc.ssl_channel_credentials(server_certificate, client_private_key,
                                                   client_certificate)
        channel = grpc.aio.secure_channel(server_address, credentials)
    stub = adder_pb2_grpc.AdderStub(channel)
    print(f"Connecting to server on {server_address}")
    a = random.randint(1, 10001)
    b = random.randint(1, 10001)
    request = adder_pb2.AddRequest(a=a, b=b)
    reply = await stub.Add(request)
    assert reply.sum == a + b
    print(f"Client: {request.a} + {request.b} = {reply.sum}")
    await channel.close()

if __name__ == "__main__":
    asyncio.run(main())
