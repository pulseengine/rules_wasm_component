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

"""Binaryen toolchain definitions for WebAssembly optimization.

Provides access to wasm-opt and other Binaryen tools for optimizing
WebAssembly modules and components.
"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

def _binaryen_toolchain_impl(ctx):
    """Implementation of binaryen_toolchain rule."""
    toolchain_info = platform_common.ToolchainInfo(
        wasm_opt = ctx.file.wasm_opt,
    )
    return [toolchain_info]

binaryen_toolchain = rule(
    implementation = _binaryen_toolchain_impl,
    attrs = {
        "wasm_opt": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-opt binary from Binaryen",
        ),
    },
    doc = "Declares a Binaryen toolchain for WebAssembly optimization",
)

def _binaryen_repository_impl(repository_ctx):
    """Create binaryen repository with downloadable binary."""
    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle if specified
    if bundle_name:
        version = get_version_for_tool(
            repository_ctx,
            "binaryen",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.version,
        )
        log_bundle_usage(repository_ctx, "binaryen", version, bundle_name)
    else:
        version = repository_ctx.attr.version

    print("Setting up binaryen {} for platform {}".format(version, platform))

    # Download binaryen
    tool_registry.download(
        repository_ctx,
        "binaryen",
        version,
        platform,
        output_name = "wasm-opt",
    )

    # Create BUILD file
    repository_ctx.file("BUILD.bazel", '''"""Binaryen toolchain repository"""

load("@rules_wasm_component//toolchains:binaryen_toolchain.bzl", "binaryen_toolchain")

package(default_visibility = ["//visibility:public"])

binaryen_toolchain(
    name = "binaryen_toolchain_impl",
    wasm_opt = ":wasm-opt",
)

toolchain(
    name = "binaryen_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":binaryen_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:binaryen_toolchain_type",
)
''')

binaryen_repository = repository_rule(
    implementation = _binaryen_repository_impl,
    attrs = {
        "version": attr.string(
            default = "123",
            doc = "Binaryen version to download",
        ),
        "bundle": attr.string(
            doc = "Version bundle name for coordinated tool versions",
        ),
    },
    doc = "Downloads Binaryen and creates a toolchain repository",
)
