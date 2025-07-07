"""Clippy configuration and rules for Rust WASM components"""

load("@rules_rust//rust:defs.bzl", "rust_clippy")

def rust_wasm_component_clippy(name, target, **kwargs):
    """Run clippy on a rust_wasm_component target.
    
    Args:
        name: Name of the clippy test target
        target: The rust_wasm_component target to run clippy on
        **kwargs: Additional arguments passed to rust_clippy
    """
    rust_clippy(
        name = name,
        deps = [target],
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