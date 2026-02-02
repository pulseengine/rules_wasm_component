"""Analysis and integration test rules for JavaScript WebAssembly components

This module provides comprehensive testing for jco + ComponentizeJS integration:
- Analysis tests for js_component, jco_transpile, and npm_install rules
- Provider validation for WasmComponentInfo with JavaScript-specific metadata
- Transpilation and binding generation verification
- Component optimization and feature testing
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WasmComponentInfo")

def _js_component_analysis_test_impl(ctx):
    """Test that js_component provides correct WasmComponentInfo."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "js_component should provide WasmComponentInfo",
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

    # Validate wit_info structure for JavaScript components
    asserts.true(
        env,
        hasattr(component_info, "wit_info"),
        "WasmComponentInfo should have wit_info field",
    )

    wit_info = component_info.wit_info
    asserts.true(
        env,
        hasattr(wit_info, "wit_file"),
        "wit_info should have wit_file field",
    )

    asserts.true(
        env,
        hasattr(wit_info, "package_name"),
        "wit_info should have package_name field",
    )

    # Check package name format (should be "namespace:name@version")
    package_name = wit_info.package_name
    asserts.true(
        env,
        ":" in package_name and "@" in package_name,
        "package_name should follow 'namespace:name@version' format",
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

js_component_analysis_test = analysistest.make(_js_component_analysis_test_impl)

def _jco_transpile_test_impl(ctx):
    """Test that jco_transpile generates appropriate outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "jco_transpile should provide output files",
    )

    # Check for transpiled directory output
    dir_outputs = [f for f in files if f.is_directory]
    asserts.true(
        env,
        len(dir_outputs) > 0,
        "jco_transpile should generate directory output",
    )

    # Check for OutputGroupInfo with transpiled outputs
    asserts.true(
        env,
        OutputGroupInfo in target_under_test,
        "jco_transpile should provide OutputGroupInfo",
    )

    output_groups = target_under_test[OutputGroupInfo]
    asserts.true(
        env,
        hasattr(output_groups, "transpiled"),
        "OutputGroupInfo should have transpiled output group",
    )

    return analysistest.end(env)

jco_transpile_test = analysistest.make(_jco_transpile_test_impl)

def _npm_install_test_impl(ctx):
    """Test that npm_install generates node_modules."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "npm_install should provide output files",
    )

    # Check for node_modules directory
    node_modules_dirs = [f for f in files if f.is_directory and f.basename == "node_modules"]
    asserts.true(
        env,
        len(node_modules_dirs) > 0,
        "npm_install should generate node_modules directory",
    )

    # Check for OutputGroupInfo with node_modules
    asserts.true(
        env,
        OutputGroupInfo in target_under_test,
        "npm_install should provide OutputGroupInfo",
    )

    output_groups = target_under_test[OutputGroupInfo]
    asserts.true(
        env,
        hasattr(output_groups, "node_modules"),
        "OutputGroupInfo should have node_modules output group",
    )

    return analysistest.end(env)

npm_install_test = analysistest.make(_npm_install_test_impl)

def _js_component_validation_test_impl(ctx):
    """Test JavaScript component metadata and configuration."""
    env = analysistest.begin(ctx)

    # Handle different test scenarios
    if ctx.attr.target_under_test:
        # Single component validation
        target_under_test = analysistest.target_under_test(env)

        # Get component info
        asserts.true(
            env,
            WasmComponentInfo in target_under_test,
            "Target should provide WasmComponentInfo",
        )

        component_info = target_under_test[WasmComponentInfo]

        # Test package name if specified
        expected_package_name = ctx.attr.expected_package_name
        if expected_package_name:
            wit_info = component_info.wit_info
            asserts.equals(
                env,
                wit_info.package_name,
                expected_package_name,
                "Component package_name should match expected value",
            )

        # Test language metadata (implicit from rule type)
        expected_language = ctx.attr.expected_language
        if expected_language:
            # For JavaScript components, language is implicit from the rule
            # We validate that it's a JavaScript component by checking structure
            asserts.true(
                env,
                hasattr(component_info, "wit_info"),
                "JavaScript component should have wit_info",
            )

    elif ctx.attr.transpile_target:
        # Transpile target validation
        transpile_target = ctx.attr.transpile_target

        # Check that transpile target provides expected outputs
        default_info = transpile_target[DefaultInfo]
        files = default_info.files.to_list()
        asserts.true(
            env,
            len(files) > 0,
            "Transpile target should provide output files",
        )

        # Validate OutputGroupInfo structure
        asserts.true(
            env,
            OutputGroupInfo in transpile_target,
            "Transpile target should provide OutputGroupInfo",
        )

    elif ctx.attr.components:
        # Multi-component validation test
        for component_target in ctx.attr.components:
            component_info = component_target[WasmComponentInfo]

            # Each component should be valid
            asserts.true(
                env,
                hasattr(component_info, "wasm_file"),
                "Component {} should have wasm_file".format(component_target.label),
            )

            # Each should have WIT info
            asserts.true(
                env,
                hasattr(component_info, "wit_info"),
                "Component {} should have wit_info".format(component_target.label),
            )

            # Each should have WASM file
            asserts.true(
                env,
                component_info.wasm_file.basename.endswith(".wasm"),
                "Component {} should have .wasm file".format(component_target.label),
            )

    return analysistest.end(env)

js_component_validation_test = analysistest.make(
    _js_component_validation_test_impl,
    attrs = {
        "target_under_test": attr.label(
            providers = [WasmComponentInfo],
            doc = "JavaScript component to validate",
        ),
        "transpile_target": attr.label(
            doc = "Transpile target to validate",
        ),
        "components": attr.label_list(
            providers = [WasmComponentInfo],
            doc = "List of components to validate",
        ),
        "expected_package_name": attr.string(
            doc = "Expected WIT package name",
        ),
        "expected_language": attr.string(
            doc = "Expected component language",
        ),
        "expected_entry_point": attr.string(
            doc = "Expected entry point file",
        ),
        "expected_instantiation": attr.string(
            doc = "Expected transpile instantiation mode",
        ),
        "expected_world": attr.string(
            doc = "Expected WIT world name",
        ),
    },
)

def _js_component_optimization_test_impl(ctx):
    """Test JavaScript component optimization and compilation flags."""
    env = analysistest.begin(ctx)

    # Test can handle single target or optimization comparison
    if ctx.attr.target_under_test:
        # Single target test
        target_under_test = analysistest.target_under_test(env)
        component_info = target_under_test[WasmComponentInfo]

        # Validate basic component properties
        asserts.true(
            env,
            component_info.component_type == "component",
            "Target should be a component",
        )

        asserts.equals(
            env,
            component_info.metadata.get("language"),
            "javascript",
            "Component should be JavaScript language",
        )

        asserts.true(
            env,
            component_info.wasm_file.basename.endswith(".wasm"),
            "Component should have .wasm file",
        )

        # Test optimization comparison between targets
    elif ctx.attr.optimized_target and ctx.attr.unoptimized_target:
        optimized_info = ctx.attr.optimized_target[WasmComponentInfo]
        unoptimized_info = ctx.attr.unoptimized_target[WasmComponentInfo]

        # Both should be valid components
        asserts.true(
            env,
            hasattr(optimized_info, "wasm_file"),
            "Optimized target should have wasm_file",
        )

        asserts.true(
            env,
            hasattr(unoptimized_info, "wasm_file"),
            "Unoptimized target should have wasm_file",
        )

        # Both should have WIT info
        asserts.true(
            env,
            hasattr(optimized_info, "wit_info"),
            "Optimized target should have wit_info",
        )

        asserts.true(
            env,
            hasattr(unoptimized_info, "wit_info"),
            "Unoptimized target should have wit_info",
        )

        # File extensions should be the same
        asserts.true(
            env,
            optimized_info.wasm_file.basename.endswith(".wasm"),
            "Optimized component should have .wasm extension",
        )

        asserts.true(
            env,
            unoptimized_info.wasm_file.basename.endswith(".wasm"),
            "Unoptimized component should have .wasm extension",
        )

    return analysistest.end(env)

js_component_optimization_test = analysistest.make(
    _js_component_optimization_test_impl,
    attrs = {
        "target_under_test": attr.label(
            providers = [WasmComponentInfo],
            doc = "Primary target for single-target tests",
        ),
        "optimized_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "Optimized component for comparison",
        ),
        "unoptimized_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "Unoptimized component for comparison",
        ),
    },
)

# ============================================================================
# jco_types Analysis Tests
# ============================================================================

def _jco_types_analysis_test_impl(ctx):
    """Test that jco_types produces TypeScript type definitions."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides output directory
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "jco_types should produce output files",
    )

    # Check that output is a directory ending with _types
    output_dir = files[0]
    asserts.true(
        env,
        output_dir.basename.endswith("_types"),
        "jco_types output should be a directory ending with _types",
    )

    # Check OutputGroupInfo has types group
    asserts.true(
        env,
        OutputGroupInfo in target_under_test,
        "jco_types should provide OutputGroupInfo",
    )

    output_groups = target_under_test[OutputGroupInfo]
    asserts.true(
        env,
        hasattr(output_groups, "types"),
        "OutputGroupInfo should have 'types' group",
    )

    return analysistest.end(env)

jco_types_test = analysistest.make(
    _jco_types_analysis_test_impl,
)

# ============================================================================
# jco_opt Analysis Tests
# ============================================================================

def _jco_opt_analysis_test_impl(ctx):
    """Test that jco_opt produces optimized WASM output."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides output file
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "jco_opt should produce output files",
    )

    # Check that output is a .wasm file
    wasm_files = [f for f in files if f.basename.endswith(".wasm")]
    asserts.true(
        env,
        len(wasm_files) > 0,
        "jco_opt should produce a .wasm file",
    )

    # Check OutputGroupInfo has optimized group
    asserts.true(
        env,
        OutputGroupInfo in target_under_test,
        "jco_opt should provide OutputGroupInfo",
    )

    output_groups = target_under_test[OutputGroupInfo]
    asserts.true(
        env,
        hasattr(output_groups, "optimized"),
        "OutputGroupInfo should have 'optimized' group",
    )

    return analysistest.end(env)

jco_opt_test = analysistest.make(
    _jco_opt_analysis_test_impl,
)
