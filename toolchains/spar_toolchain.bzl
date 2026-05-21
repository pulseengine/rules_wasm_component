# Copyright 2026 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

"""spar toolchain: AADL v2.3 architecture toolchain.

spar generates WIT interfaces from AADL architecture models (`spar codegen
--format wit`). It is distributed as per-platform tar.gz/zip archives with a
flat layout (the `spar` binary at the archive root).
"""

load("//checksums:registry.bzl", "validate_tool_exists")
load("//toolchains:tool_registry.bzl", "tool_registry")

# Platforms where spar release archives are published.
_SUPPORTED_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
    "windows_amd64",
]

def _spar_toolchain_impl(ctx):
    """Implementation of spar_toolchain rule."""
    return [platform_common.ToolchainInfo(
        spar = ctx.file.spar,
    )]

spar_toolchain = rule(
    implementation = _spar_toolchain_impl,
    attrs = {
        "spar": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "spar binary for AADL-to-WIT generation",
        ),
    },
    doc = "Declares a spar toolchain for AADL architecture model processing",
)

_STUB_BUILD = '''"""spar toolchain stub: unsupported platform.

spar has no release archive for this host, so we register a toolchain marked
incompatible with any target. Toolchain resolution for aadl_wit_library
targets fails cleanly here; builds that never touch aadl_wit_library are
unaffected.
"""

load("@rules_wasm_component//toolchains:spar_toolchain.bzl", "spar_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["spar_stub"])

spar_toolchain(
    name = "spar_toolchain_impl",
    spar = "spar_stub",
)

toolchain(
    name = "spar_toolchain",
    target_compatible_with = ["@platforms//:incompatible"],
    toolchain = ":spar_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:spar_toolchain_type",
)
'''

def _spar_repository_impl(repository_ctx):
    """Download the spar archive and create a toolchain repository."""
    platform = tool_registry.detect_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Unsupported/unknown host: emit a stub so module resolution still works.
    if platform not in _SUPPORTED_PLATFORMS or not validate_tool_exists(repository_ctx, "spar", version, platform):
        print("spar: no release archive for platform {} (version {}); emitting stub".format(platform, version))
        repository_ctx.file("spar_stub", content = "", executable = True)
        repository_ctx.file("BUILD.bazel", _STUB_BUILD)
        return

    print("Setting up spar {} for platform {}".format(version, platform))

    # Archives are flat: the binary sits at the archive root.
    bin_name = "spar.exe" if platform.startswith("windows") else "spar"

    # Extract the release archive into dist/.
    tool_registry.download(
        repository_ctx,
        "spar",
        version,
        platform,
        output_dir = "dist",
    )

    repository_ctx.file("BUILD.bazel", '''"""spar toolchain repository"""

load("@rules_wasm_component//toolchains:spar_toolchain.bzl", "spar_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["dist/{bin}"])

spar_toolchain(
    name = "spar_toolchain_impl",
    spar = "dist/{bin}",
)

toolchain(
    name = "spar_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":spar_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:spar_toolchain_type",
)
'''.format(bin = bin_name))

spar_repository = repository_rule(
    implementation = _spar_repository_impl,
    attrs = {
        "version": attr.string(
            default = "0.9.3",
            doc = "spar version to download",
        ),
    },
    doc = "Downloads spar and creates a toolchain repository",
)
