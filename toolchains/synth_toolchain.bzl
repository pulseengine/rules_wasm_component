# Copyright 2026 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

"""synth toolchain: WebAssembly-to-ARM ahead-of-time compiler.

synth compiles a WebAssembly core module to a bare-metal ARM Cortex-M ELF —
the final stage of the PulseEngine pipeline. It is distributed as per-platform
tar.gz archives with a flat layout (the `synth` binary at the archive root).
No Windows binary is published.
"""

load("//checksums:registry.bzl", "validate_tool_exists")
load("//toolchains:tool_registry.bzl", "tool_registry")

# Platforms where synth release archives are published (no Windows).
_SUPPORTED_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
]

def _synth_toolchain_impl(ctx):
    """Implementation of synth_toolchain rule."""
    return [platform_common.ToolchainInfo(
        synth = ctx.file.synth,
    )]

synth_toolchain = rule(
    implementation = _synth_toolchain_impl,
    attrs = {
        "synth": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "synth binary for WebAssembly-to-ARM compilation",
        ),
    },
    doc = "Declares a synth toolchain for ahead-of-time ARM compilation",
)

_STUB_BUILD = '''"""synth toolchain stub: unsupported platform.

synth publishes no release archive for this host (e.g. Windows), so we
register a toolchain marked incompatible with any target. Toolchain
resolution for synth_compile targets fails cleanly here; builds that never
touch synth_compile are unaffected.
"""

load("@rules_wasm_component//toolchains:synth_toolchain.bzl", "synth_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["synth_stub"])

synth_toolchain(
    name = "synth_toolchain_impl",
    synth = "synth_stub",
)

toolchain(
    name = "synth_toolchain",
    target_compatible_with = ["@platforms//:incompatible"],
    toolchain = ":synth_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:synth_toolchain_type",
)
'''

def _synth_repository_impl(repository_ctx):
    """Download the synth archive and create a toolchain repository."""
    platform = tool_registry.detect_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Unsupported host (Windows / unknown): emit a stub so module resolution
    # still works. synth_compile targets simply won't be buildable there.
    if platform not in _SUPPORTED_PLATFORMS or not validate_tool_exists(repository_ctx, "synth", version, platform):
        print("synth: no release archive for platform {} (version {}); emitting stub".format(platform, version))
        repository_ctx.file("synth_stub", content = "", executable = True)
        repository_ctx.file("BUILD.bazel", _STUB_BUILD)
        return

    print("Setting up synth {} for platform {}".format(version, platform))

    # Extract the release archive into dist/ (flat layout: dist/synth).
    tool_registry.download(
        repository_ctx,
        "synth",
        version,
        platform,
        output_dir = "dist",
    )

    repository_ctx.file("BUILD.bazel", '''"""synth toolchain repository"""

load("@rules_wasm_component//toolchains:synth_toolchain.bzl", "synth_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["dist/synth"])

synth_toolchain(
    name = "synth_toolchain_impl",
    synth = "dist/synth",
)

toolchain(
    name = "synth_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":synth_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:synth_toolchain_type",
)
''')

synth_repository = repository_rule(
    implementation = _synth_repository_impl,
    attrs = {
        "version": attr.string(
            default = "0.3.1",
            doc = "synth version to download",
        ),
    },
    doc = "Downloads synth and creates a toolchain repository",
)
