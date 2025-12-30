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
    #
    # Check multiple possible indicators of Windows:
    # 1. host_platform label might contain "windows"
    # 2. cpu setting might be x86_64 or x64_windows
    # 3. Default to adding .exe suffix on any platform with "windows" in cpu string
    host_platform = str(settings.get("//command_line_option:host_platform", ""))
    cpu = str(settings.get("//command_line_option:cpu", ""))

    # Windows detection: check both platform and CPU strings
    is_windows = "windows" in host_platform.lower() or "windows" in cpu.lower() or "x64_windows" in cpu

    # Get current rustc flags from the rules_rust extra_rustc_flags setting
    # Note: This is a list of strings
    current_flags = list(settings.get("@rules_rust//rust/settings:extra_rustc_flags", []))

    # Windows-specific linker configuration for wasm32-wasip2
    # Discovery: wasm-component-ld.exe EXISTS in rustc distribution at:
    #   rustc/lib/rustlib/x86_64-pc-windows-msvc/bin/wasm-component-ld.exe
    # But rustc can't find it by name alone. We need to help it.
    if is_windows:
        # Try using -Clink-self-contained=yes to force rustc to use its own linker tools
        # This should make it search in lib/rustlib/{target}/bin/
        current_flags.extend(["-Clink-self-contained=yes"])

        # Also explicitly point to the linker using the target-specific path
        # Rustc should resolve this relative to its sysroot
        current_flags.extend(["-Clinker=wasm-component-ld.exe"])

    return {
        "//command_line_option:platforms": "//platforms:wasm32-wasip2",
        "@rules_rust//rust/settings:extra_rustc_flags": current_flags,
    }

wasm_transition = transition(
    implementation = _wasm_transition_impl,
    inputs = [
        "//command_line_option:host_platform",
        "//command_line_option:cpu",
        "@rules_rust//rust/settings:extra_rustc_flags",
    ],
    outputs = [
        "//command_line_option:platforms",
        "@rules_rust//rust/settings:extra_rustc_flags",
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
