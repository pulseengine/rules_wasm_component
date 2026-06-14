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

"""WASM utility rules - PUBLIC API

STABILITY: Public API
The rules and macros in this file are the public API of rules_wasm_component
for WASM utilities. They are subject to semantic versioning guarantees:
- Major version: Breaking changes allowed
- Minor version: Backwards-compatible additions
- Patch version: Bug fixes only

DO NOT depend on //wasm/private - those are implementation details.

This module provides utilities for:
- Component validation (wasm_validate)
- Component creation (wasm_component_new)
- Pre-initialization (wasm_component_wizer, wizer_chain)
- Optimization (wasm_optimize, binaryen_optimize)
- Cryptographic signing (wasm_keygen, wasm_sign, wasm_verify)
- AOT compilation (wasm_precompile, wasm_precompile_multi)
- Runtime execution (wasm_run, wasm_test)
- AOT embedding (wasm_embed_aot, wasm_extract_aot)
- Component fusion (meld_fuse)
- ARM cross-compilation (synth_compile)
- Sigil transformation attestation (wasm_attest, wasm_verify_chain, wasm_show_chain)

Example usage:

    load("//wasm:defs.bzl", "wasm_validate", "wasm_precompile")

    wasm_validate(
        name = "my_component_validated",
        component = ":my_component",
    )

    wasm_precompile(
        name = "my_component_aot",
        component = ":my_component",
    )
"""

load(
    "//wasm/private:binaryen_optimize.bzl",
    _binaryen_optimize = "binaryen_optimize",
)
load(
    "//wasm/private:meld_fuse.bzl",
    _meld_fuse = "meld_fuse",
)
load(
    "//wasm/private:aadl_wit_library.bzl",
    _aadl_wit_library = "aadl_wit_library",
)
load(
    "//wasm/private:wasm_module_coverage.bzl",
    _wasm_module_coverage = "wasm_module_coverage",
)
load(
    "//wasm/private:ssh_keygen.bzl",
    _ssh_keygen = "ssh_keygen",
)
load(
    "//wasm/private:synth_compile.bzl",
    _synth_compile = "synth_compile",
)
load(
    "//wasm/private:wasm_aot_aspect.bzl",
    _wasm_aot_aspect = "wasm_aot_aspect",
    _wasm_aot_config = "wasm_aot_config",
)
load(
    "//wasm/private:wasm_component_new.bzl",
    _wasm_component_new = "wasm_component_new",
)
load(
    "//wasm/private:wasm_component_wizer.bzl",
    _wasm_component_wizer = "wasm_component_wizer",
    _wizer_chain = "wizer_chain",
)
load(
    "//wasm/private:wasm_embed_aot.bzl",
    _wasm_embed_aot = "wasm_embed_aot",
    _wasm_extract_aot = "wasm_extract_aot",
)
load(
    "//wasm/private:wasm_component_import.bzl",
    _wasm_component_import = "wasm_component_import",
)
load(
    "//wasm/private:wasm_optimize.bzl",
    _wasm_optimize = "wasm_optimize",
)
load(
    "//wasm/private:wasm_precompile.bzl",
    _wasm_precompile = "wasm_precompile",
    _wasm_precompile_multi = "wasm_precompile_multi",
)
load(
    "//wasm/private:wasm_run.bzl",
    _wasm_run = "wasm_run",
    _wasm_test = "wasm_test",
)
load(
    "//wasm/private:wasm_signing.bzl",
    _wasm_keygen = "wasm_keygen",
    _wasm_sign = "wasm_sign",
    _wasm_verify = "wasm_verify",
)
load(
    "//wasm/private:wsc_attestation.bzl",
    _wasm_attest = "wasm_attest",
    _wasm_show_chain = "wasm_show_chain",
    _wasm_verify_chain = "wasm_verify_chain",
)
load(
    "//wasm/private:wasm_validate.bzl",
    _wasm_validate = "wasm_validate",
)

# Re-export public rules
wasm_validate = _wasm_validate
wasm_component_new = _wasm_component_new
wasm_component_wizer = _wasm_component_wizer
wizer_chain = _wizer_chain

# WebAssembly signing rules
wasm_keygen = _wasm_keygen
wasm_sign = _wasm_sign
wasm_verify = _wasm_verify

# Sigil transformation attestation rules (wsc 0.7.0+)
wasm_attest = _wasm_attest
wasm_verify_chain = _wasm_verify_chain
wasm_show_chain = _wasm_show_chain

# WebAssembly AOT compilation rules
wasm_precompile = _wasm_precompile
wasm_precompile_multi = _wasm_precompile_multi
wasm_run = _wasm_run
wasm_test = _wasm_test
wasm_aot_aspect = _wasm_aot_aspect
wasm_aot_config = _wasm_aot_config

# WebAssembly AOT embedding rules
wasm_embed_aot = _wasm_embed_aot
wasm_extract_aot = _wasm_extract_aot

# SSH key generation (for signing workflows)
ssh_keygen = _ssh_keygen

# WebAssembly optimization rules
wasm_component_import = _wasm_component_import
wasm_optimize = _wasm_optimize
binaryen_optimize = _binaryen_optimize

# PulseEngine pipeline rules
aadl_wit_library = _aadl_wit_library
meld_fuse = _meld_fuse
synth_compile = _synth_compile
wasm_module_coverage = _wasm_module_coverage
