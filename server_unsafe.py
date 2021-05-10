import asyncio
from grpclib.server import Server
from grpclib.utils import graceful_exit
from adder_pb2 import AddReply
from adder_grpc import AdderBase

class AdderServer(AdderBase):

    async def Add(self, stream) -> None:
        request = await stream.recv_message()
        reply = AddReply(sum=request.a + request.b)
        await stream.send_message(reply)
         # pylint:disable=no-member
        print(f"Server: {request.a} + {request.b} = {reply.sum}")

async def serve(host="127.0.0.1", port=50051):
    server = Server([AdderServer()])
    with graceful_exit([server]):
        await server.start(host, port)
        await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(serve())
