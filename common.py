import argparse

# TODO: Can server determine client-name in certificate from context?
# TODO: If yes, add command-line option to let server validate client-name.

def parse_command_line_arguments(role):
    parser = argparse.ArgumentParser(description=f"Secure gRPC demo {role}")
    parser.add_argument(
        "--authentication", "-a",
        type=str,
        choices=["none", "server", "mutual"],
        default="none",
        help="Authentication: none, server, or mutual (default: none)")
    parser.add_argument(
        "--server-host", "-s",
        type=str,
        default="localhost",
        help="The server host name (default: localhost)")
    parser.add_argument(
        "--server-name", "-S",
        type=str,
        help="Server name override, if different from the server host name.")
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
