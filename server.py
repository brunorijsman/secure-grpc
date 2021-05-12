#!/usr/bin/env python

import argparse
import asyncio
import grpc
import adder_pb2
import adder_pb2_grpc

class Adder(adder_pb2_grpc.AdderServicer):

    async def Add(self, request, context):
        reply = adder_pb2.AddReply(sum=request.a + request.b)
        print(f"Server: {request.a} + {request.b} = {reply.sum}")
        return reply

def parse_command_line_arguments():
    parser = argparse.ArgumentParser(description="Secure gRPC demo server")
    parser.add_argument(
        "authentication",
        choices=["none", "tls"],
        default="none",
        help="Authentication mechanism")
    return parser.parse_args()

async def server_insecure():
    server = grpc.aio.server()
    server.add_insecure_port("localhost:50051")
    adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server)
    await server.start()
    await server.wait_for_termination()

async def server_tls():
    private_key = open("server.key", "br").read()
    certificate = open("server.crt", "br").read()
    credentials = grpc.ssl_server_credentials([(private_key, certificate)])
    server = grpc.aio.server()
    server.add_secure_port("localhost:50051", credentials)
    adder_pb2_grpc.add_AdderServicer_to_server(Adder(), server)
    await server.start()
    print("Started TLS server on localhost:50051")
    await server.wait_for_termination()

if __name__ == "__main__":
    args = parse_command_line_arguments()
    if args.authentication == "none":
        asyncio.run(server_insecure())
    elif args.authentication == "tls":
        asyncio.run(server_tls())
    else:
        assert False
