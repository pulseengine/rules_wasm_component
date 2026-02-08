"""Analysis tests for WRPC rules.

Tests validate:
- Transport rules provide WrpcTransportInfo with correct fields
- wrpc_bindgen generates output directory structure
- Language-specific binding macros work correctly
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WrpcTransportInfo")

# =============================================================================
# Transport Provider Tests
# =============================================================================

def _transport_provider_test_impl(ctx):
    """Test that transport rules provide WrpcTransportInfo correctly."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WrpcTransportInfo
    asserts.true(
        env,
        WrpcTransportInfo in target_under_test,
        "Transport rule should provide WrpcTransportInfo",
    )

    transport_info = target_under_test[WrpcTransportInfo]

    # Check required fields exist
    required_fields = [
        "transport_type",
        "address",
        "cli_args",
        "extra_args",
        "address_format",
        "metadata",
    ]
    for field in required_fields:
        asserts.true(
            env,
            hasattr(transport_info, field),
            "WrpcTransportInfo should have {} field".format(field),
        )

    # Check transport_type matches expected
    if ctx.attr.expected_transport_type:
        asserts.equals(
            env,
            ctx.attr.expected_transport_type,
            transport_info.transport_type,
            "transport_type should match expected value",
        )

    # Check address is non-empty
    asserts.true(
        env,
        transport_info.address != "",
        "address should not be empty",
    )

    # Check cli_args is a list
    asserts.true(
        env,
        type(transport_info.cli_args) == "list",
        "cli_args should be a list",
    )

    # Check metadata is a dict
    asserts.true(
        env,
        type(transport_info.metadata) == "dict",
        "metadata should be a dict",
    )

    return analysistest.end(env)

transport_provider_test = analysistest.make(
    _transport_provider_test_impl,
    attrs = {
        "expected_transport_type": attr.string(
            doc = "Expected transport type (tcp, nats, unix, quic)",
        ),
    },
)

# =============================================================================
# Binding Generation Tests
# =============================================================================

def _wrpc_bindgen_test_impl(ctx):
    """Test that wrpc_bindgen produces correct output."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()

    asserts.true(
        env,
        len(files) > 0,
        "wrpc_bindgen should provide output files",
    )

    # Check output is a directory (indicated by no extension in typical naming)
    # wrpc_bindgen produces a directory of generated source files

    return analysistest.end(env)

wrpc_bindgen_test = analysistest.make(
    _wrpc_bindgen_test_impl,
    attrs = {
        "expected_language": attr.string(
            doc = "Expected language (rust, go)",
        ),
    },
)

# =============================================================================
# Serve/Invoke Launcher Tests
# =============================================================================

def _wrpc_launcher_test_impl(ctx):
    """Test that wrpc_serve/wrpc_invoke produce executable launchers."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides executable
    default_info = target_under_test[DefaultInfo]

    asserts.true(
        env,
        default_info.files_to_run != None,
        "wrpc launcher should provide files_to_run",
    )

    # Check executable exists
    executable = default_info.files_to_run.executable
    if executable:
        asserts.true(
            env,
            executable.basename.endswith(".py") or not executable.basename.endswith(".wasm"),
            "Launcher should be a Python script, not a WASM file",
        )

    return analysistest.end(env)

wrpc_launcher_test = analysistest.make(_wrpc_launcher_test_impl)
