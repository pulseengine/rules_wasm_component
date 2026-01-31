"""Analysis test rules for MoonBit WebAssembly components.

This module provides testing for MoonBit component integration:
- Analysis tests for moonbit_wasm_component rule
- Provider validation for WasmComponentInfo with MoonBit-specific metadata
- Signed integer type tests for upstream bug tracking (#1518)

Related upstream issues:
- bytecodealliance/wit-bindgen#1518: s8/s16 lift corruption
- bytecodealliance/wit-bindgen#1517: async, flags, Option<T> issues
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WasmComponentInfo")

def _moonbit_component_analysis_test_impl(ctx):
    """Test that moonbit_wasm_component provides correct WasmComponentInfo."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "moonbit_wasm_component should provide WasmComponentInfo",
    )

    component_info = target_under_test[WasmComponentInfo]

    # Validate WASM file output
    asserts.true(
        env,
        hasattr(component_info, "wasm_file"),
        "WasmComponentInfo should have wasm_file field",
    )

    wasm_file = component_info.wasm_file
    asserts.true(
        env,
        wasm_file.basename.endswith(".wasm"),
        "wasm_file should have .wasm extension",
    )

    # MoonBit components should be "reactor" type (library component)
    asserts.true(
        env,
        hasattr(component_info, "component_type"),
        "WasmComponentInfo should have component_type field",
    )

    asserts.equals(
        env,
        component_info.component_type,
        "reactor",
        "MoonBit components should be type 'reactor'",
    )

    # Validate metadata contains MoonBit-specific information
    asserts.true(
        env,
        hasattr(component_info, "metadata"),
        "WasmComponentInfo should have metadata field",
    )

    metadata = component_info.metadata
    asserts.equals(
        env,
        metadata.get("language"),
        "moonbit",
        "Component metadata should indicate 'moonbit' language",
    )

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "Target should provide output files",
    )

    # Check that the main WASM file is in the output
    wasm_files = [f for f in files if f.basename.endswith(".wasm")]
    asserts.true(
        env,
        len(wasm_files) > 0,
        "Target should provide .wasm output files",
    )

    return analysistest.end(env)

moonbit_component_analysis_test = analysistest.make(_moonbit_component_analysis_test_impl)

def _moonbit_signed_integers_test_impl(ctx):
    """Test MoonBit component with signed integer types (s8, s16).

    This test validates that components using s8/s16 types build successfully.
    Note: The upstream bug (#1518) causes value corruption at runtime, not build time.
    This test catches build regressions; runtime testing requires wasmtime invocation.
    """
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "Signed integers component should provide WasmComponentInfo",
    )

    component_info = target_under_test[WasmComponentInfo]

    # Verify the component built successfully
    asserts.true(
        env,
        component_info.wasm_file.basename.endswith(".wasm"),
        "Component should produce .wasm file",
    )

    # Verify it's a reactor (library) component
    asserts.equals(
        env,
        component_info.component_type,
        "reactor",
        "Signed integers test should be a reactor component",
    )

    # Verify exports list includes the signed integer functions
    # Note: exports may be empty if WIT parsing is incomplete
    exports = component_info.exports
    if exports:
        # If exports are populated, verify we have the expected ones
        expected_exports = ["signed-integers"]
        for expected in expected_exports:
            asserts.true(
                env,
                expected in exports,
                "Component should export '{}'".format(expected),
            )

    return analysistest.end(env)

moonbit_signed_integers_test = analysistest.make(_moonbit_signed_integers_test_impl)

def moonbit_test_suite(name):
    """Creates the MoonBit component test suite.

    Args:
        name: Name of the test suite target.
    """
    native.test_suite(
        name = name,
        tests = [
            ":moonbit_component_analysis_test",
            ":signed_integers_analysis_test",
        ],
        # MoonBit toolchain only available on darwin_arm64, linux_amd64, windows_amd64
        tags = ["manual"],
    )
