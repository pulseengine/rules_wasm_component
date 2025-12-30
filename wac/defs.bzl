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

"""WAC (WebAssembly Composition) rules - PUBLIC API

STABILITY: Public API

The rules and macros in this file are the public API of rules_wasm_component
for WAC composition. They are subject to semantic versioning guarantees:
- Major version: Breaking changes allowed
- Minor version: Backwards-compatible additions
- Patch version: Bug fixes only

DO NOT depend on //wac/private - those are implementation details.

Available rules:
    wac_compose: Compose multiple WebAssembly components
    wac_plug: Plug a component into another component's socket
    wac_bundle: Bundle multiple components into a single archive
    wac_remote_compose: Compose components with remote dependencies

Example usage:

    wac_compose(
        name = "composed_app",
        components = [
            ":frontend_component",
            ":backend_component",
        ],
        config = "compose.wac",
    )

    wac_plug(
        name = "plugged_component",
        socket = ":base_component",
        plug = ":plugin_component",
    )
"""

load(
    "//wac/private:wac_bundle.bzl",
    _wac_bundle = "wac_bundle",
)
load(
    "//wac/private:wac_compose.bzl",
    _wac_compose = "wac_compose",
)
load(
    "//wac/private:wac_plug.bzl",
    _wac_plug = "wac_plug",
)
load(
    "//wac/private:wac_remote_compose.bzl",
    _wac_remote_compose = "wac_remote_compose",
)

# Re-export public rules
wac_compose = _wac_compose
wac_plug = _wac_plug
wac_bundle = _wac_bundle
wac_remote_compose = _wac_remote_compose
