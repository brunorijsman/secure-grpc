import argparse

def parse_command_line_arguments(role):
    parser = argparse.ArgumentParser(description=f"Secure gRPC demo {role}")
    parser.add_argument(
        "--authentication", "-a",
        type=str,
        choices=["none", "server", "mutual"],
        default="none",
        help="Authentication: none, server, or mutual (default: none)")
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
    parser.add_argument(
        "--signer", "-i",
        type=str,
        choices=["self", "ca"],
        default="self",
        help=("Signer for server and client certificates: self or ca (certificate authority) "
              "(default: self)"))
    args = parser.parse_args()
    return args

def authentication_and_signer_summary(args):
    assert args.authentication in ["none", "server", "mutual"]
    assert args.signer in ["self", "ca"]
    if args.authentication == "none":
        return "No authentication"
    assert args.authentication in ["server", "mutual"]
    return f"{args.authentication} {args.signer}-signed authentication"
