"""Analysis and integration test rules for Go WebAssembly components

This module provides comprehensive testing for TinyGo + WASI Preview 2 integration:
- Analysis tests for go_wasm_component and go_wit_bindgen rules
- Provider validation for WasmComponentInfo with Go-specific metadata
- WIT binding generation verification
- Component export and optimization profile testing
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WasmComponentInfo", "WitInfo")

def _go_component_analysis_test_impl(ctx):
    """Test that go_wasm_component provides correct WasmComponentInfo."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "go_wasm_component should provide WasmComponentInfo",
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

    # Validate component type for Go components
    asserts.true(
        env,
        hasattr(component_info, "component_type"),
        "WasmComponentInfo should have component_type field",
    )

    asserts.equals(
        env,
        component_info.component_type,
        "component",
        "Go components should be type 'component'",
    )

    # Validate metadata contains Go-specific information
    asserts.true(
        env,
        hasattr(component_info, "metadata"),
        "WasmComponentInfo should have metadata field",
    )

    metadata = component_info.metadata
    asserts.equals(
        env,
        metadata.get("language"),
        "go",
        "Component metadata should indicate 'go' language",
    )

    asserts.equals(
        env,
        metadata.get("target"),
        "wasm32-wasip2",
        "Component metadata should indicate wasm32-wasip2 target",
    )

    # Validate TinyGo version information
    tinygo_version = metadata.get("tinygo_version")
    asserts.true(
        env,
        tinygo_version and "0.38" in tinygo_version,
        "Component metadata should contain TinyGo version >= 0.38",
    )

    # Check profile field
    asserts.true(
        env,
        hasattr(component_info, "profile"),
        "WasmComponentInfo should have profile field",
    )

    profile = component_info.profile
    asserts.true(
        env,
        profile in ["debug", "release"],
        "Profile should be either 'debug' or 'release'",
    )

    # Validate DefaultInfo provides files
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

go_component_analysis_test = analysistest.make(_go_component_analysis_test_impl)

def _go_wit_bindgen_test_impl(ctx):
    """Test that go_wit_bindgen generates appropriate outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "go_wit_bindgen should provide output files",
    )

    # Check for Go binding files (even if placeholder)
    go_files = [f for f in files if f.basename.endswith(".go")]
    asserts.true(
        env,
        len(go_files) > 0,
        "go_wit_bindgen should generate .go files",
    )

    return analysistest.end(env)

go_wit_bindgen_test = analysistest.make(_go_wit_bindgen_test_impl)

def _go_component_exports_test_impl(ctx):
    """Test that Go components export expected interfaces."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Get component info
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "Target should provide WasmComponentInfo",
    )

    component_info = target_under_test[WasmComponentInfo]

    # Test exports field
    asserts.true(
        env,
        hasattr(component_info, "exports"),
        "WasmComponentInfo should have exports field",
    )

    exports = component_info.exports

    # Check expected world is exported
    expected_world = ctx.attr.expected_world
    if expected_world:
        asserts.true(
            env,
            expected_world in exports,
            "Component should export world '{}'".format(expected_world),
        )

    # Validate metadata matches expected language
    expected_language = ctx.attr.expected_language
    if expected_language:
        metadata = component_info.metadata
        asserts.equals(
            env,
            metadata.get("language"),
            expected_language,
            "Component language should be '{}'".format(expected_language),
        )

    return analysistest.end(env)

go_component_exports_test = analysistest.make(
    _go_component_exports_test_impl,
    attrs = {
        "expected_world": attr.string(
            doc = "Expected WIT world name in exports",
        ),
        "expected_language": attr.string(
            doc = "Expected component language in metadata",
        ),
    },
)

def _go_component_validation_test_impl(ctx):
    """Test Go component build profiles and validation."""
    env = analysistest.begin(ctx)

    # Test can handle either single target or profile comparison
    if ctx.attr.release_target and ctx.attr.debug_target:
        # Profile comparison test
        release_target = ctx.attr.release_target[WasmComponentInfo]
        debug_target = ctx.attr.debug_target[WasmComponentInfo]

        # Both should be valid components
        asserts.true(
            env,
            release_target.component_type == "component",
            "Release target should be a component",
        )

        asserts.true(
            env,
            debug_target.component_type == "component",
            "Debug target should be a component",
        )

        # Profile metadata should differ
        asserts.equals(
            env,
            release_target.profile,
            "release",
            "Release target should have 'release' profile",
        )

        asserts.equals(
            env,
            debug_target.profile,
            "debug",
            "Debug target should have 'debug' profile",
        )

        # Both should have same language and target
        asserts.equals(
            env,
            release_target.metadata.get("language"),
            debug_target.metadata.get("language"),
            "Both profiles should have same language",
        )

        asserts.equals(
            env,
            release_target.metadata.get("target"),
            debug_target.metadata.get("target"),
            "Both profiles should have same target",
        )

    elif ctx.attr.components:
        # Multi-component validation test
        for component_target in ctx.attr.components:
            component_info = component_target[WasmComponentInfo]

            # Each component should be valid
            asserts.true(
                env,
                component_info.component_type == "component",
                "Component {} should be type 'component'".format(component_target.label),
            )

            # Each should have Go metadata
            asserts.equals(
                env,
                component_info.metadata.get("language"),
                "go",
                "Component {} should be Go language".format(component_target.label),
            )

            # Each should have WASM file
            asserts.true(
                env,
                component_info.wasm_file.basename.endswith(".wasm"),
                "Component {} should have .wasm file".format(component_target.label),
            )

    return analysistest.end(env)

go_component_validation_test = analysistest.make(
    _go_component_validation_test_impl,
    attrs = {
        "release_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "Release profile component for comparison",
        ),
        "debug_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "Debug profile component for comparison",
        ),
        "components": attr.label_list(
            providers = [WasmComponentInfo],
            doc = "List of components to validate",
        ),
    },
)
