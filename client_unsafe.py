import asyncio
from grpclib.client import Channel
from adder_pb2 import AddRequest
from adder_grpc import AdderStub

async def run_client():
    async with Channel("127.0.0.1", 50051) as channel:
        stub = AdderStub(channel=channel)
        request = AddRequest(a=1, b=2)
        reply = await stub.Add(request)
        assert reply.sum == 3
        print(f"Client: {request.a} + {request.b} = {reply.sum}")

if __name__ == "__main__":
    asyncio.run(run_client())
