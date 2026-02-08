"""WRPC Transport Configuration Rules (Phase 3 WRPC modernization)

This module provides pluggable transport configuration for WRPC rules.
Instead of hardcoded transport strings, users define transport configurations
as Bazel targets that can be validated at BUILD time and reused across rules.

Supported transports:
- TCP: Direct TCP connections (tcp_transport)
- NATS: NATS.io messaging (nats_transport)
- Unix: Unix domain sockets (unix_transport)
- QUIC: QUIC protocol (quic_transport)

Example:
    load("@rules_wasm_component//wrpc:transports.bzl", "tcp_transport")

    tcp_transport(
        name = "dev_server",
        address = "localhost:8080",
    )

    wrpc_serve(
        name = "serve",
        component = ":my_component",
        transport = ":dev_server",
    )
"""

load("//providers:providers.bzl", "WrpcTransportInfo")

# =============================================================================
# Address Validation Utilities
# =============================================================================

def _validate_host_port(address, transport_name):
    """Validate host:port address format."""
    if ":" not in address:
        fail("{} address must include port (host:port), got: {}".format(
            transport_name, address))

    parts = address.rsplit(":", 1)
    if len(parts) != 2:
        fail("{} address must be host:port, got: {}".format(
            transport_name, address))

    host, port = parts
    if not port.isdigit():
        fail("{} port must be numeric, got: {}".format(transport_name, port))

    port_num = int(port)
    if port_num < 1 or port_num > 65535:
        fail("{} port must be 1-65535, got: {}".format(transport_name, port_num))

    return True

# =============================================================================
# TCP Transport
# =============================================================================

def _tcp_transport_impl(ctx):
    """TCP transport configuration."""
    address = ctx.attr.address
    _validate_host_port(address, "TCP")

    return [
        WrpcTransportInfo(
            transport_type = "tcp",
            address = address,
            cli_args = ["tcp", "serve"],
            extra_args = [],
            address_format = "host:port (e.g., localhost:8080, 0.0.0.0:8080)",
            config_file = None,
            metadata = {},
        ),
    ]

tcp_transport = rule(
    implementation = _tcp_transport_impl,
    attrs = {
        "address": attr.string(
            doc = "TCP address in host:port format (e.g., localhost:8080)",
            mandatory = True,
        ),
    },
    doc = """Configure TCP transport for WRPC.

    TCP is the simplest transport, suitable for direct point-to-point connections.

    Example:
        tcp_transport(
            name = "server_tcp",
            address = "0.0.0.0:8080",
        )
    """,
)

# =============================================================================
# NATS Transport
# =============================================================================

def _nats_transport_impl(ctx):
    """NATS.io transport configuration."""
    address = ctx.attr.address

    # NATS URLs should start with nats://
    if not address.startswith("nats://"):
        fail("NATS address must start with nats://, got: {}".format(address))

    # Validate the host:port part after nats://
    host_port = address[7:]  # Skip "nats://"
    if ":" not in host_port:
        fail("NATS address must include port (nats://host:port), got: {}".format(address))

    extra_args = []
    if ctx.attr.prefix:
        extra_args.extend(["--prefix", ctx.attr.prefix])

    return [
        WrpcTransportInfo(
            transport_type = "nats",
            address = address,
            cli_args = ["nats", "serve"],
            extra_args = extra_args,
            address_format = "nats://host:port (e.g., nats://localhost:4222)",
            config_file = ctx.file.config if ctx.attr.config else None,
            metadata = {
                "prefix": ctx.attr.prefix,
            },
        ),
    ]

nats_transport = rule(
    implementation = _nats_transport_impl,
    attrs = {
        "address": attr.string(
            doc = "NATS server URL (nats://host:port)",
            mandatory = True,
        ),
        "prefix": attr.string(
            doc = "Subject prefix for NATS messages",
            default = "",
        ),
        "config": attr.label(
            doc = "Optional NATS configuration file",
            allow_single_file = True,
        ),
    },
    doc = """Configure NATS transport for WRPC.

    NATS provides pub/sub messaging, suitable for multi-component routing
    and service discovery patterns. Requires NATS server >= 2.10.20.

    Example:
        nats_transport(
            name = "nats_prod",
            address = "nats://nats.example.com:4222",
            prefix = "my-service",
        )
    """,
)

# =============================================================================
# Unix Domain Socket Transport
# =============================================================================

def _unix_transport_impl(ctx):
    """Unix domain socket transport configuration."""
    socket_path = ctx.attr.socket_path

    if not socket_path.startswith("/"):
        fail("Unix socket path must be absolute (start with /), got: {}".format(socket_path))

    return [
        WrpcTransportInfo(
            transport_type = "unix",
            address = socket_path,
            cli_args = ["tcp", "serve"],  # Unix uses tcp subcommand with socket path
            extra_args = [],
            address_format = "/path/to/socket (e.g., /tmp/wrpc.sock)",
            config_file = None,
            metadata = {},
        ),
    ]

unix_transport = rule(
    implementation = _unix_transport_impl,
    attrs = {
        "socket_path": attr.string(
            doc = "Absolute path to Unix domain socket",
            mandatory = True,
        ),
    },
    doc = """Configure Unix domain socket transport for WRPC.

    Unix sockets provide high-performance IPC on the same host.
    Only works on Unix-like systems (Linux, macOS).

    Example:
        unix_transport(
            name = "local_socket",
            socket_path = "/tmp/my_service.sock",
        )
    """,
)

# =============================================================================
# QUIC Transport
# =============================================================================

def _quic_transport_impl(ctx):
    """QUIC transport configuration."""
    address = ctx.attr.address
    _validate_host_port(address, "QUIC")

    extra_args = []
    if ctx.attr.insecure:
        extra_args.append("--insecure")

    return [
        WrpcTransportInfo(
            transport_type = "quic",
            address = address,
            cli_args = ["tcp", "serve"],  # QUIC may use different subcommand
            extra_args = extra_args,
            address_format = "host:port (e.g., localhost:4433)",
            config_file = None,
            metadata = {
                "insecure": ctx.attr.insecure,
            },
        ),
    ]

quic_transport = rule(
    implementation = _quic_transport_impl,
    attrs = {
        "address": attr.string(
            doc = "QUIC address in host:port format",
            mandatory = True,
        ),
        "insecure": attr.bool(
            doc = "Disable TLS verification (for testing only)",
            default = False,
        ),
    },
    doc = """Configure QUIC transport for WRPC.

    QUIC provides encrypted, multiplexed transport with built-in
    congestion control. Good for unreliable networks.

    Example:
        quic_transport(
            name = "secure_quic",
            address = "0.0.0.0:4433",
        )
    """,
)
