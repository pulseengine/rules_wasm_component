# Copyright 2024 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rust WebAssembly Component Model rules

State-of-the-art Rust support for WebAssembly Component Model using:
- Rust 1.88.0+ with native WASI Preview 2 support
- Bazel-native implementation following modern patterns
- Cross-platform compatibility (Windows/macOS/Linux)
- Advanced optimization with Wizer pre-initialization
- Clippy integration for code quality
- Comprehensive test framework support
- Component composition and macro system

Example usage:

    rust_wasm_component(
        name = "my_service",
        srcs = ["lib.rs", "service.rs"],
        wit = "//wit:service-interface",
        world = "service",
        optimization = "release",
        enable_wizer = True,
    )

    rust_wasm_component_test(
        name = "my_service_test",
        component = ":my_service",
        test_data = ["test_input.json"],
    )
"""

load(
    "//rust:clippy.bzl",
    _rust_clippy_all = "rust_clippy_all",
    _rust_wasm_component_clippy = "rust_wasm_component_clippy",
)
load(
    "//rust:rust_wasm_component.bzl",
    _rust_wasm_component = "rust_wasm_component",
)
load(
    "//rust:rust_wasm_component_bindgen.bzl",
    _rust_wasm_component_bindgen = "rust_wasm_component_bindgen",
)
load(
    "//rust:rust_wasm_component_test.bzl",
    _rust_wasm_component_test = "rust_wasm_component_test",
)
load(
    "//rust:rust_wasm_component_wizer.bzl",
    _rust_wasm_component_wizer = "rust_wasm_component_wizer",
)
load(
    "//rust:rust_wasm_binary.bzl",
    _rust_wasm_binary = "rust_wasm_binary",
)

# Re-export public rules
rust_wasm_component = _rust_wasm_component
rust_wasm_component_test = _rust_wasm_component_test
rust_wasm_component_bindgen = _rust_wasm_component_bindgen
rust_wasm_component_wizer = _rust_wasm_component_wizer
rust_wasm_component_clippy = _rust_wasm_component_clippy
rust_clippy_all = _rust_clippy_all
rust_wasm_binary = _rust_wasm_binary
