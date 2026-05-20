# Copyright 2026 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

"""witness toolchain: MC/DC branch coverage for WebAssembly core modules.

witness instruments a WASM core module, executes it, and reports MC/DC-style
branch coverage. It is distributed as per-platform tar.gz/zip archives with a
flat layout (the `witness` binary at the archive root).
"""

load("//checksums:registry.bzl", "validate_tool_exists")
load("//toolchains:tool_registry.bzl", "tool_registry")

# Platforms where witness release archives are published.
_SUPPORTED_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
    "windows_amd64",
]

def _witness_toolchain_impl(ctx):
    """Implementation of witness_toolchain rule."""
    return [platform_common.ToolchainInfo(
        witness = ctx.file.witness,
    )]

witness_toolchain = rule(
    implementation = _witness_toolchain_impl,
    attrs = {
        "witness": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "witness binary for WASM coverage instrumentation",
        ),
    },
    doc = "Declares a witness toolchain for WebAssembly coverage measurement",
)

_STUB_BUILD = '''"""witness toolchain stub: unsupported platform.

witness has no release archive for this host, so we register a toolchain
marked incompatible with any target. Toolchain resolution for
wasm_module_coverage targets fails cleanly here; builds that never touch
wasm_module_coverage are unaffected.
"""

load("@rules_wasm_component//toolchains:witness_toolchain.bzl", "witness_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["witness_stub"])

witness_toolchain(
    name = "witness_toolchain_impl",
    witness = "witness_stub",
)

toolchain(
    name = "witness_toolchain",
    target_compatible_with = ["@platforms//:incompatible"],
    toolchain = ":witness_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:witness_toolchain_type",
)
'''

def _witness_repository_impl(repository_ctx):
    """Download the witness archive and create a toolchain repository."""
    platform = tool_registry.detect_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Unsupported/unknown host: emit a stub so module resolution still works.
    if platform not in _SUPPORTED_PLATFORMS or not validate_tool_exists(repository_ctx, "witness", version, platform):
        print("witness: no release archive for platform {} (version {}); emitting stub".format(platform, version))
        repository_ctx.file("witness_stub", content = "", executable = True)
        repository_ctx.file("BUILD.bazel", _STUB_BUILD)
        return

    print("Setting up witness {} for platform {}".format(version, platform))

    # Archives are flat: the binary sits at the archive root.
    bin_name = "witness.exe" if platform.startswith("windows") else "witness"

    # Extract the release archive into dist/.
    tool_registry.download(
        repository_ctx,
        "witness",
        version,
        platform,
        output_dir = "dist",
    )

    repository_ctx.file("BUILD.bazel", '''"""witness toolchain repository"""

load("@rules_wasm_component//toolchains:witness_toolchain.bzl", "witness_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["dist/{bin}"])

witness_toolchain(
    name = "witness_toolchain_impl",
    witness = "dist/{bin}",
)

toolchain(
    name = "witness_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":witness_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:witness_toolchain_type",
)
'''.format(bin = bin_name))

witness_repository = repository_rule(
    implementation = _witness_repository_impl,
    attrs = {
        "version": attr.string(
            default = "0.22.0",
            doc = "witness version to download",
        ),
    },
    doc = "Downloads witness and creates a toolchain repository",
)
