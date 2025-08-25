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

    # Use WASI Preview 2 - now Tier 2 support in Rust 1.82+
    return {
        "//command_line_option:platforms": "//platforms:wasm32-wasip2",
    }

wasm_transition = transition(
    implementation = _wasm_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
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
