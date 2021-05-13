#!/usr/bin/env python

import asyncio
import grpc
import adder_pb2
import adder_pb2_grpc
from common import parse_command_line_arguments

class Adder(adder_pb2_grpc.AdderServicer):

    async def Add(self, request, context):
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply

def make_credentials(args):
    assert args.authentication in ["server", "mutual"]
    assert args.signer in ["self", "root-ca", "intermediate-ca"]
    server_private_key = open("server.key", "br").read()
    server_certificate = open("server.crt", "br").read()
    private_key_certificate_chain_pairs = [(server_private_key, server_certificate)]
    if args.authentication == "mutual":
        if args.signer == "self":
            print("Mutual self-signed authentication")
            root_certificate = open("client.crt", "br").read()
        elif args.signer == "root-ca":
            print("Mutual root CA signed authentication")
            root_certificate = open("root-ca.crt", "br").read()
        else:
            print("Mutual intermediate CA signed authentication")
            root_certificate = open("intermediate-ca.crt", "br").read()
    else:
        print("Server authentication")
        root_certificate = None
    credentials = grpc.ssl_server_credentials(private_key_certificate_chain_pairs,
                                              root_certificate, True)
    return credentials

async def main():
    args = parse_command_line_arguments("server")
    server = grpc.aio.server()
    server_address = f"{args.server_host}:{args.server_port}"
    if args.authentication == "none":
        print("No authentication")
        server.add_insecure_port(server_address)
    else:
        credentials = make_credentials(args)
        server.add_secure_port(server_address, credentials)
    adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server)
    await server.start()
    print(f"Started server on {server_address}")
    await server.wait_for_termination()

if __name__ == "__main__":
    asyncio.run(main())
