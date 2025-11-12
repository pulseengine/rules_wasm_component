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

"""Platform transitions for WASM component builds"""

def _wasm_transition_impl(settings, attr):
    """Transition to WASM platform for component builds"""

    # Detect Windows execution platform for wasm-component-ld.exe workaround
    # On Windows, the linker needs .exe extension but Rust's wasm32-wasip2 target spec doesn't add it
    host_platform = str(settings["//command_line_option:host_platform"])
    is_windows = "windows" in host_platform

    # Get current rustc flags
    rustc_flags = list(settings.get("@rules_rust//:extra_rustc_flags", []))

    # Add Windows-specific linker configuration
    if is_windows:
        # Override the linker for wasm32-wasip2 on Windows hosts
        rustc_flags.extend(["-C", "linker=wasm-component-ld.exe"])

    return {
        "//command_line_option:platforms": "//platforms:wasm32-wasip2",
        "@rules_rust//:extra_rustc_flags": rustc_flags,
    }

wasm_transition = transition(
    implementation = _wasm_transition_impl,
    inputs = [
        "//command_line_option:host_platform",
        "@rules_rust//:extra_rustc_flags",
    ],
    outputs = [
        "//command_line_option:platforms",
        "@rules_rust//:extra_rustc_flags",
    ],
)

def _wasm_unknown_transition_impl(settings, attr):
    """Transition to WASM unknown platform for bare metal builds"""
    return {
        "//command_line_option:platforms": "//platforms:wasm32-unknown-unknown",
    }

wasm_unknown_transition = transition(
    implementation = _wasm_unknown_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
    ],
)
