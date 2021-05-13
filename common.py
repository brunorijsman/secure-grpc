import argparse
import sys

def parse_command_line_arguments(role):
    parser = argparse.ArgumentParser(description=f"Secure gRPC demo {role}")
    parser.add_argument(
        "--authentication", "-A",
        type=str,
        choices=["none", "server", "mutual"],
        default="none",
        help="Authentication: none, server, or mutual (default: none)")
    parser.add_argument(
        "--ca-signed", "-r",
        action="store_true",
        default=False,
        help=("Use certificate authority (CA) signed certificates (default: use self-signed "
              "certificates)"))
    parser.add_argument(
        "--client-host", "-c",
        type=str,
        default="localhost",
        help="The client hostname (default: localhost)")
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
    args = parser.parse_args()
    return args
