"""Clippy configuration and rules for Rust WASM components"""

load("@rules_rust//rust:defs.bzl", "rust_clippy")

def rust_wasm_component_clippy(name, target, profile = "release", **kwargs):
    """Run clippy on a rust_wasm_component target.

    Args:
        name: Name of the clippy test target
        target: The rust_wasm_component target to run clippy on
        profile: The profile to run clippy on (default: "release")
        **kwargs: Additional arguments passed to rust_clippy
    """

    # Point to the underlying rust library, not the component
    rust_lib_target = "{}_wasm_lib_{}".format(target, profile)
    rust_clippy(
        name = name,
        deps = [rust_lib_target],
        **kwargs
    )

def rust_clippy_all(name, targets, **kwargs):
    """Run clippy on multiple Rust targets.

    Args:
        name: Name of the test suite
        targets: List of Rust targets to run clippy on
        **kwargs: Additional arguments passed to test_suite
    """
    clippy_targets = []
    for target in targets:
        clippy_name = "{}_clippy".format(target.split(":")[-1])
        rust_clippy(
            name = clippy_name,
            deps = [target],
        )
        clippy_targets.append(":" + clippy_name)

    native.test_suite(
        name = name,
        tests = clippy_targets,
        **kwargs
    )
