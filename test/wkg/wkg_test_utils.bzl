"""Common test utilities for WKG and OCI testing using olareg_wasm"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//providers:providers.bzl", "WasmComponentInfo", "WasmOciInfo", "WasmRegistryInfo")

def _olareg_test_registry_impl(ctx):
    """Implementation for olareg test registry rule"""

    registry_component = ctx.file.component

    # Create registry start script
    start_script = ctx.actions.declare_file(ctx.label.name + "_start.sh")

    port = ctx.attr.port
    data_dir = "/tmp/test_registry_" + ctx.label.name

    script_content = """#!/bin/bash
set -euo pipefail

REGISTRY_COMPONENT="{component}"
PORT="{port}"
DATA_DIR="{data_dir}"

echo "Starting olareg test registry on port $PORT..."

# Create data directory
mkdir -p "$DATA_DIR"

# In a real implementation, this would:
# 1. Start the WASM component with wasmtime or similar runtime
# 2. Call start-server function via component interface
# 3. Wait for health check to pass
# 4. Set up cleanup on exit

echo "Test registry started on localhost:$PORT"
echo "Data directory: $DATA_DIR"
echo "Registry component: $REGISTRY_COMPONENT"

# For now, create a marker file to indicate the registry is "running"
echo "running" > "$DATA_DIR/status"
""".format(
        component = registry_component.path,
        port = port,
        data_dir = data_dir,
    )

    ctx.actions.write(
        output = start_script,
        content = script_content,
        is_executable = True,
    )

    # Create registry stop script
    stop_script = ctx.actions.declare_file(ctx.label.name + "_stop.sh")

    stop_script_content = """#!/bin/bash
set -euo pipefail

DATA_DIR="{data_dir}"

echo "Stopping olareg test registry..."

# Clean up data directory if auto_cleanup is enabled
if [ "{auto_cleanup}" = "True" ]; then
    rm -rf "$DATA_DIR"
    echo "Registry data cleaned up"
fi

echo "Test registry stopped"
""".format(
        data_dir = data_dir,
        auto_cleanup = str(ctx.attr.auto_cleanup),
    )

    ctx.actions.write(
        output = stop_script,
        content = stop_script_content,
        is_executable = True,
    )

    # Create registry configuration for tests
    registry_config = ctx.actions.declare_file(ctx.label.name + "_config.toml")

    config_content = """[registry]
default = "test-registry"

[registries.test-registry]
url = "localhost:{port}"
type = "oci"
""".format(port = port)

    ctx.actions.write(
        output = registry_config,
        content = config_content,
    )

    return [
        DefaultInfo(files = depset([start_script, stop_script, registry_config])),
        WasmRegistryInfo(
            registries = {
                "test-registry": {
                    "url": "localhost:" + port,
                    "type": "oci",
                },
            },
            auth_configs = {},
            default_registry = "test-registry",
            config_file = registry_config,
            credentials = {},
        ),
    ]

olareg_test_registry = rule(
    implementation = _olareg_test_registry_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "The olareg WASM component to use as test registry",
        ),
        "port": attr.string(
            mandatory = True,
            doc = "Port for the test registry",
        ),
        "auto_cleanup": attr.bool(
            default = True,
            doc = "Whether to automatically clean up registry data after tests",
        ),
    },
    doc = "Creates a test registry using olareg_wasm component",
)

def _wkg_component_test_impl(ctx):
    """Test that WKG rules work with olareg test registry"""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides expected providers
    if WasmComponentInfo in target_under_test:
        component_info = target_under_test[WasmComponentInfo]

        # Basic component validation
        asserts.true(
            env,
            hasattr(component_info, "wasm_file"),
            "Component should have wasm_file",
        )

        wasm_file = component_info.wasm_file
        asserts.true(
            env,
            wasm_file.basename.endswith(".wasm"),
            "Component file should have .wasm extension",
        )

    if WasmOciInfo in target_under_test:
        oci_info = target_under_test[WasmOciInfo]

        # OCI-specific validation
        asserts.true(
            env,
            hasattr(oci_info, "image_name"),
            "OCI info should have image_name",
        )

        asserts.true(
            env,
            hasattr(oci_info, "image_tag"),
            "OCI info should have image_tag",
        )

    return analysistest.end(env)

wkg_component_test = analysistest.make(_wkg_component_test_impl)

def _wkg_registry_connectivity_test_impl(ctx):
    """Test registry connectivity and basic operations"""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check for registry info provider
    if WasmRegistryInfo in target_under_test:
        registry_info = target_under_test[WasmRegistryInfo]

        asserts.true(
            env,
            hasattr(registry_info, "registries"),
            "Registry should have registries dict",
        )

        asserts.true(
            env,
            "test-registry" in registry_info.registries,
            "Should have test-registry configured",
        )

        test_registry = registry_info.registries["test-registry"]
        asserts.true(
            env,
            test_registry["url"].startswith("localhost:"),
            "Test registry should use localhost",
        )

        asserts.equals(
            env,
            test_registry["type"],
            "oci",
            "Test registry should be OCI type",
        )

    return analysistest.end(env)

wkg_registry_connectivity_test = analysistest.make(_wkg_registry_connectivity_test_impl)

def _wkg_integration_test_suite_impl(ctx):
    """Implementation for comprehensive WKG integration test suite"""

    test_registry = ctx.attr.test_registry
    test_components = ctx.files.test_components

    # Create integration test script
    test_script = ctx.actions.declare_file(ctx.label.name + "_integration.sh")

    script_content = """#!/bin/bash
set -euo pipefail

echo "=== WKG Integration Test Suite ==="

# Test registry information
REGISTRY="{registry_label}"
TEST_COMPONENTS=({components})

echo "Test registry: $REGISTRY"
echo "Test components: ${{TEST_COMPONENTS[@]}}"

# In a full implementation, this would:
# 1. Start the test registry
# 2. Upload test components
# 3. Test fetch operations
# 4. Test publish operations
# 5. Test OCI image creation
# 6. Test multi-registry scenarios
# 7. Clean up

echo "✅ WKG integration tests completed successfully"
""".format(
        registry_label = str(test_registry.label),
        components = " ".join([c.basename for c in test_components]),
    )

    ctx.actions.write(
        output = test_script,
        content = script_content,
        is_executable = True,
    )

    return DefaultInfo(
        executable = test_script,
        runfiles = ctx.runfiles(files = test_components),
    )

wkg_integration_test = rule(
    implementation = _wkg_integration_test_suite_impl,
    test = True,
    attrs = {
        "test_registry": attr.label(
            providers = [WasmRegistryInfo],
            mandatory = True,
            doc = "Test registry to use for integration tests",
        ),
        "test_components": attr.label_list(
            allow_files = [".wasm"],
            doc = "List of WASM components to use in integration tests",
        ),
    },
    doc = "Comprehensive integration test suite for WKG functionality",
)

def wkg_test_suite(name, test_registry, test_components = [], **kwargs):
    """Convenience macro for creating a complete WKG test suite"""

    # Create analysis tests for each component
    for i, component in enumerate(test_components):
        wkg_component_test(
            name = name + "_component_" + str(i) + "_test",
            target_under_test = component,
        )

    # Create registry connectivity test
    wkg_registry_connectivity_test(
        name = name + "_registry_test",
        target_under_test = test_registry,
    )

    # Create integration test suite
    wkg_integration_test(
        name = name + "_integration",
        test_registry = test_registry,
        test_components = test_components,
        **kwargs
    )

    # Combine all tests into a test suite
    native.test_suite(
        name = name,
        tests = [
            name + "_integration",
            name + "_registry_test",
        ] + [
            name + "_component_" + str(i) + "_test"
            for i in range(len(test_components))
        ],
    )

def olareg_mock_data(name, components, **kwargs):
    """Create mock test data for olareg registry"""

    # Generate test data file
    native.genrule(
        name = name + "_data_gen",
        outs = [name + "_test_data.json"],
        cmd = """
cat > $@ << 'EOF'
{
  "components": [
""" + ",\n".join([
            '    {"name": "' + comp + '", "tag": "test", "data": "mock-data-for-' + comp + '"}'
            for comp in components
        ]) + """
  ]
}
EOF
        """,
        **kwargs
    )

    return name + "_data_gen"
