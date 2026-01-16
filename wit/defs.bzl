# Copyright 2025 Ralf Anton Beier. All rights reserved.
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

"""WIT (WebAssembly Interface Types) rules - PUBLIC API

STABILITY: Public API

The rules and macros in this file are the public API of rules_wasm_component
for WIT interface handling. They are subject to semantic versioning guarantees:
- Major version: Breaking changes allowed
- Minor version: Backwards-compatible additions
- Patch version: Bug fixes only

DO NOT depend on //wit/private - those are implementation details.

Available rules:
    wit_library: Define a WIT library with interface definitions
    wit_bindgen: Generate language bindings from WIT
    symmetric_wit_bindgen: Generate symmetric bindings
    wit_markdown: Generate Markdown documentation from WIT
    wit_docs_collection: Collect WIT documentation

Example usage:

    wit_library(
        name = "calculator_wit",
        srcs = ["calculator.wit"],
        package = "example:calculator@1.0.0",
    )

    wit_bindgen(
        name = "calculator_bindings",
        wit = ":calculator_wit",
        language = "rust",
        world = "calculator",
    )
"""

load(
    "//wit/private:wit_bindgen.bzl",
    _wit_bindgen = "wit_bindgen",
)
load(
    "//wit/private:symmetric_wit_bindgen.bzl",
    _symmetric_wit_bindgen = "symmetric_wit_bindgen",
)
load(
    "//wit/private:wit_library.bzl",
    _wit_library = "wit_library",
)
load(
    "//wit/private:wit_markdown.bzl",
    _wit_docs_collection = "wit_docs_collection",
    _wit_markdown = "wit_markdown",
)
load(
    "//wit/private:wasi_deps.bzl",
    _wasi_wit_dependencies = "wasi_wit_dependencies",
)
load(
    "//wit/private:wit_deps_check.bzl",
    _wit_deps_check = "wit_deps_check",
)
load(
    "//wit/private:wit_vendor.bzl",
    _vendored_wit_library = "vendored_wit_library",
    _wit_package = "wit_package",
    _wit_vendor_lock = "wit_vendor_lock",
)

# Re-export public rules
wit_library = _wit_library
wit_bindgen = _wit_bindgen
symmetric_wit_bindgen = _symmetric_wit_bindgen
wit_markdown = _wit_markdown
wit_docs_collection = _wit_docs_collection
wasi_wit_dependencies = _wasi_wit_dependencies
wit_deps_check = _wit_deps_check

# Air-gap/vendoring support
wit_package = _wit_package
vendored_wit_library = _vendored_wit_library
wit_vendor_lock = _wit_vendor_lock
