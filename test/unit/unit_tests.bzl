"""Unit test rules for rules_wasm_component using Bazel analysis tests."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_wasm_component//providers:providers.bzl", "WasmComponentInfo", "WitInfo")

def _wit_library_test_impl(ctx):
    """Test that wit_library targets provide correct WitInfo."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WitInfo
    asserts.true(
        env,
        WitInfo in target_under_test,
        "wit_library should provide WitInfo",
    )

    wit_info = target_under_test[WitInfo]

    # Check that package_name is set
    asserts.true(
        env,
        hasattr(wit_info, "package_name"),
        "WitInfo should have package_name field",
    )

    asserts.true(
        env,
        wit_info.package_name != "",
        "package_name should not be empty",
    )

    # Check that wit_files is a depset
    asserts.true(
        env,
        hasattr(wit_info, "wit_files"),
        "WitInfo should have wit_files field",
    )

    wit_files_list = wit_info.wit_files.to_list()
    asserts.true(
        env,
        len(wit_files_list) > 0,
        "wit_files should not be empty",
    )

    # Check file extensions
    for f in wit_files_list:
        asserts.true(
            env,
            f.basename.endswith(".wit"),
            "All wit_files should have .wit extension",
        )

    return analysistest.end(env)

wit_library_test = analysistest.make(_wit_library_test_impl)

def _rust_component_test_impl(ctx):
    """Test that rust_wasm_component_bindgen targets provide correct outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check that target provides WasmComponentInfo
    asserts.true(
        env,
        WasmComponentInfo in target_under_test,
        "rust_wasm_component_bindgen should provide WasmComponentInfo",
    )

    component_info = target_under_test[WasmComponentInfo]

    # Check that wasm_file is provided
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

    # Check that wit_info is embedded
    asserts.true(
        env,
        hasattr(component_info, "wit_info"),
        "WasmComponentInfo should have wit_info field",
    )

    # Check default info provides files
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()
    asserts.true(
        env,
        len(files) > 0,
        "Target should provide output files",
    )

    return analysistest.end(env)

rust_component_test = analysistest.make(_rust_component_test_impl)

def _wac_compose_test_impl(ctx):
    """Test that wac_compose targets produce valid outputs."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Check default output
    default_info = target_under_test[DefaultInfo]
    files = default_info.files.to_list()

    asserts.true(
        env,
        len(files) > 0,
        "wac_compose should provide output files",
    )

    # Find the main .wasm output
    wasm_files = [f for f in files if f.basename.endswith(".wasm")]
    asserts.true(
        env,
        len(wasm_files) > 0,
        "wac_compose should produce .wasm output",
    )

    return analysistest.end(env)

wac_compose_test = analysistest.make(_wac_compose_test_impl)

def _provider_test_impl(ctx):
    """Test provider fields and structure."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    if WitInfo in target_under_test:
        wit_info = target_under_test[WitInfo]

        # Test WitInfo structure
        required_fields = ["package_name", "wit_files", "wit_deps"]
        for field in required_fields:
            asserts.true(
                env,
                hasattr(wit_info, field),
                "WitInfo should have {} field".format(field),
            )

        # Test wit_deps is a depset
        asserts.true(
            env,
            type(wit_info.wit_deps) == "depset",
            "wit_deps should be a depset",
        )

    if WasmComponentInfo in target_under_test:
        component_info = target_under_test[WasmComponentInfo]

        # Test WasmComponentInfo structure
        required_fields = ["wasm_file", "wit_info"]
        for field in required_fields:
            asserts.true(
                env,
                hasattr(component_info, field),
                "WasmComponentInfo should have {} field".format(field),
            )

    return analysistest.end(env)

provider_test = analysistest.make(_provider_test_impl)
