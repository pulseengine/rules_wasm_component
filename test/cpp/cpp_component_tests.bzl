"""Analysis and integration test rules for C/C++ WebAssembly components

This module provides comprehensive testing for WASI SDK + clang integration:
- Analysis tests for cpp_component, cpp_wit_bindgen, and cc_component_library rules
- Provider validation for WasmComponentInfo with C/C++-specific metadata
- Language variant testing (C vs C++ compilation)
- Component library dependency and standards testing
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WasmComponentInfo")

def _cpp_component_analysis_test_impl(ctx):
    """Test that cpp_component provides correct WasmComponentInfo."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "cpp_component should provide WasmComponentInfo",
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

    # Validate component type for C/C++ components
    asserts.true(
        env,
        hasattr(component_info, "component_type"),
        "WasmComponentInfo should have component_type field",
    )

    # C/C++ components should be "component" type after embedding WIT metadata
    asserts.equals(
        env,
        component_info.component_type,
        "component",
        "C/C++ components should be type 'component'",
    )

    # Validate metadata contains C/C++-specific information
    asserts.true(
        env,
        hasattr(component_info, "metadata"),
        "WasmComponentInfo should have metadata field",
    )

    metadata = component_info.metadata
    language = metadata.get("language")
    asserts.true(
        env,
        language in ["c", "cpp"],
        "Component metadata should indicate 'c' or 'cpp' language",
    )

    asserts.equals(
        env,
        metadata.get("target"),
        "wasm32-wasip2",
        "Component metadata should indicate wasm32-wasip2 target",
    )

    # Validate toolchain information
    toolchain = metadata.get("toolchain")
    asserts.true(
        env,
        toolchain and "wasi-sdk" in toolchain,
        "Component metadata should contain WASI SDK toolchain info",
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

cpp_component_analysis_test = analysistest.make(_cpp_component_analysis_test_impl)

def _cpp_wit_bindgen_test_impl(ctx):
    """Test that cpp_wit_bindgen generates appropriate outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "cpp_wit_bindgen should provide output files",
    )

    # Check that cpp_wit_bindgen provides a bindings directory
    # The rule outputs a directory containing the generated .h, .c/.cpp files
    asserts.true(
        env,
        len(files) > 0,
        "cpp_wit_bindgen should provide bindings directory",
    )

    # Verify it's a directory by checking the path ends with "_bindings"
    has_bindings_dir = any([f.path.endswith("_bindings") for f in files])
    asserts.true(
        env,
        has_bindings_dir,
        "cpp_wit_bindgen should generate C/C++ bindings directory",
    )

    return analysistest.end(env)

cpp_wit_bindgen_test = analysistest.make(_cpp_wit_bindgen_test_impl)

def _cc_component_library_test_impl(ctx):
    """Test that cc_component_library generates appropriate outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check DefaultInfo provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "cc_component_library should provide output files",
    )

    # Check for compiled library files (headers should be available)
    header_files = [f for f in files if f.basename.endswith((".h", ".hpp"))]
    # Note: Component libraries may not generate .a files directly in some toolchains

    # Validate CcInfo provider if available (standard C++ provider)
    if CcInfo in target_under_test:
        cc_info = target_under_test[CcInfo]
        asserts.true(
            env,
            hasattr(cc_info, "compilation_context"),
            "CcInfo should have compilation_context",
        )

    return analysistest.end(env)

cc_component_library_test = analysistest.make(_cc_component_library_test_impl)

def _cpp_component_language_test_impl(ctx):
    """Test C vs C++ language variant differences."""
    env = analysistest.begin(ctx)

    # Test can handle single target or C vs C++ comparison
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

        language = component_info.metadata.get("language")
        asserts.true(
            env,
            language in ["c", "cpp"],
            "Component should be C or C++ language",
        )

        asserts.true(
            env,
            component_info.wasm_file.basename.endswith(".wasm"),
            "Component should have .wasm file",
        )

        # Test language variant comparison between C and C++ targets
    elif ctx.attr.c_target and ctx.attr.cpp_target:
        c_info = ctx.attr.c_target[WasmComponentInfo]
        cpp_info = ctx.attr.cpp_target[WasmComponentInfo]

        # Both should be valid components
        asserts.true(
            env,
            c_info.component_type == "component",
            "C target should be a component",
        )

        asserts.true(
            env,
            cpp_info.component_type == "component",
            "C++ target should be a component",
        )

        # Language metadata should differ
        c_language = c_info.metadata.get("language")
        cpp_language = cpp_info.metadata.get("language")

        asserts.equals(
            env,
            c_language,
            "c",
            "C target should have 'c' language",
        )

        asserts.equals(
            env,
            cpp_language,
            "cpp",
            "C++ target should have 'cpp' language",
        )

        # Both should have same target platform
        asserts.equals(
            env,
            c_info.metadata.get("target"),
            cpp_info.metadata.get("target"),
            "Both C and C++ should target same platform",
        )

        # Both should use WASI SDK toolchain
        c_toolchain = c_info.metadata.get("toolchain", "")
        cpp_toolchain = cpp_info.metadata.get("toolchain", "")

        asserts.true(
            env,
            "wasi-sdk" in c_toolchain,
            "C component should use WASI SDK toolchain",
        )

        asserts.true(
            env,
            "wasi-sdk" in cpp_toolchain,
            "C++ component should use WASI SDK toolchain",
        )

    return analysistest.end(env)

cpp_component_language_test = analysistest.make(
    _cpp_component_language_test_impl,
    attrs = {
        "target_under_test": attr.label(
            providers = [WasmComponentInfo],
            doc = "Primary target for single-target tests",
        ),
        "c_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "C component for comparison",
        ),
        "cpp_target": attr.label(
            providers = [WasmComponentInfo],
            doc = "C++ component for comparison",
        ),
    },
)

def _cpp_component_validation_test_impl(ctx):
    """Test C/C++ component features and validation."""
    env = analysistest.begin(ctx)

    # Test can handle either single target or multi-component validation
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

        # Test language if specified
        expected_language = ctx.attr.expected_language
        if expected_language:
            metadata = component_info.metadata
            asserts.equals(
                env,
                metadata.get("language"),
                expected_language,
                "Component language should be '{}'".format(expected_language),
            )

        # Test C++ standard if specified
        expected_cxx_std = ctx.attr.expected_cxx_std
        if expected_cxx_std:
            metadata = component_info.metadata
            cxx_std = metadata.get("cxx_std")
            asserts.equals(
                env,
                cxx_std,
                expected_cxx_std,
                "Component C++ standard should be '{}'".format(expected_cxx_std),
            )

        # Test optimization if specified
        expected_optimization = ctx.attr.expected_optimization
        if expected_optimization != -1:  # -1 means don't check
            metadata = component_info.metadata
            optimization = metadata.get("optimization", False)
            expected_bool = expected_optimization == 1
            asserts.equals(
                env,
                optimization,
                expected_bool,
                "Component optimization should be {}".format(expected_bool),
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

            # Each should have C/C++ metadata
            language = component_info.metadata.get("language")
            asserts.true(
                env,
                language in ["c", "cpp"],
                "Component {} should be C or C++ language".format(component_target.label),
            )

            # Each should have WASM file
            asserts.true(
                env,
                component_info.wasm_file.basename.endswith(".wasm"),
                "Component {} should have .wasm file".format(component_target.label),
            )

            # Each should target WASI Preview 2
            target = component_info.metadata.get("target")
            asserts.equals(
                env,
                target,
                "wasm32-wasip2",
                "Component {} should target wasm32-wasip2".format(component_target.label),
            )

    return analysistest.end(env)

cpp_component_validation_test = analysistest.make(
    _cpp_component_validation_test_impl,
    attrs = {
        "target_under_test": attr.label(
            providers = [WasmComponentInfo],
            doc = "C/C++ component to validate",
        ),
        "components": attr.label_list(
            providers = [WasmComponentInfo],
            doc = "List of components to validate",
        ),
        "expected_language": attr.string(
            doc = "Expected component language (c or cpp)",
        ),
        "expected_cxx_std": attr.string(
            doc = "Expected C++ standard (e.g., c++20)",
        ),
        "expected_optimization": attr.int(
            default = -1,
            doc = "Expected optimization setting (1=True, 0=False, -1=don't check)",
        ),
    },
)
