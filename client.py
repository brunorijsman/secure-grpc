#!/usr/bin/env python

import asyncio
import random
import grpc
import adder_pb2
import adder_pb2_grpc
import common

def make_credentials(args):
    assert args.authentication in ["server", "mutual"]
    assert args.signer in ["self", "ca"]
    if args.signer == "self":
        root_certificate_for_server = open("certs/server.crt", "br").read()
    else:
        root_certificate_for_server = open("certs/root.crt", "br").read()
    if args.authentication == "mutual":
        client_private_key = open("keys/client.key", "br").read()
        client_certificate_chain = open("certs/client.pem", "br").read()
        credentials = grpc.ssl_channel_credentials(root_certificate_for_server, client_private_key,
                                                   client_certificate_chain)
    else:
        credentials = grpc.ssl_channel_credentials(root_certificate_for_server)
    return credentials

async def main():
    args = common.parse_command_line_arguments("server")
    print(f"Client: {common.authentication_and_signer_summary(args)}")
    server_address = f"{args.server_host}:{args.server_port}"
    if args.authentication == "none":
        channel = grpc.aio.insecure_channel(server_address)
    else:
        credentials = make_credentials(args)
        channel = grpc.aio.secure_channel(server_address, credentials)
    stub = adder_pb2_grpc.AdderStub(channel)
    print(f"Client: connect to {server_address}")
    a = random.randint(1, 10001)
    b = random.randint(1, 10001)
    request = adder_pb2.AddRequest(a=a, b=b)
    reply = await stub.Add(request)
    assert reply.sum == a + b
    print(f"Client: {request.a} + {request.b} = {reply.sum}")
    await channel.close()

if __name__ == "__main__":
    asyncio.run(main())
