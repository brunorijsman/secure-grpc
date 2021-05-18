#!/usr/bin/env python

import asyncio
import grpc
import adder_pb2
import adder_pb2_grpc
import common

class Adder(adder_pb2_grpc.AdderServicer):

    async def Add(self, request, context):
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply

def make_credentials(args):
    assert args.authentication in ["server", "mutual"]
    assert args.signer in ["self", "root", "intermediate"]
    server_private_key = open("keys/server.key", "br").read()
    server_certificate_chain = open("certs/server.pem", "br").read()
    private_key_certificate_chain_pairs = [(server_private_key, server_certificate_chain)]
    if args.authentication == "mutual":
        if args.signer == "self":
            root_certificate_for_client = open("certs/client.crt", "br").read()
        elif args.signer == "root":
            root_certificate_for_client = open("certs/root.crt", "br").read()
        else:
            root_certificate_for_client = open("certs/intermediate.crt", "br").read()
        credentials = grpc.ssl_server_credentials(private_key_certificate_chain_pairs,
                                                root_certificate_for_client, True)
    else:
        credentials = grpc.ssl_server_credentials(private_key_certificate_chain_pairs)
    return credentials

async def main():
    args = common.parse_command_line_arguments("server")
    print(f"Server: {common.authentication_and_signer_summary(args)}")
    server = grpc.aio.server()
    server_address = f"{args.server_host}:{args.server_port}"
    if args.authentication == "none":
        server.add_insecure_port(server_address)
    else:
        credentials = make_credentials(args)
        server.add_secure_port(server_address, credentials)
    adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server)
    await server.start()
    print(f"Server: listening on {server_address}")
    await server.wait_for_termination()

if __name__ == "__main__":
    asyncio.run(main())
