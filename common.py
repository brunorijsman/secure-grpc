import argparse

def parse_command_line_arguments(role):
    parser = argparse.ArgumentParser(description=f"Secure gRPC demo {role}")
    parser.add_argument(
        "--client-authenticated", "-C",
        action="store_true",
        default=False,
        help="The client is authenticated by the server (default: client is not authenticated)")
    parser.add_argument(
        "--client-host", "-c",
        type=str,
        default="localhost",
        help="The client hostname (default: localhost)")
    parser.add_argument(
        "--server-authenticated", "-S",
        action="store_true",
        default=False,
        help="The server is authenticated by the client (default: server is not authenticated)")
    parser.add_argument(
        "--server-host", "-s",
        type=str,
        default="localhost",
        help="The server hostname (default: localhost)")
    parser.add_argument(
        "--server-port", "-p",
        type=int,
        default=50051,
        help="The server port (default: 50051)")
    parser.add_argument(
        "--ca-signed", "-a",
        action="store_true",
        default=False,
        help="Use CA-signed certificates (default: use self-signed certificates)")
    return parser.parse_args()
