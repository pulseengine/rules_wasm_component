# Copyright 2026 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

"""Meld toolchain: native binary for static WebAssembly component fusion.

Meld merges multiple WebAssembly components into a single core module,
resolving inter-component imports at build time. Unlike loom and wsc,
meld is distributed as native binaries (no wasm variant) to keep the
fusion pipeline fast on large component graphs.
"""

load("//checksums:registry.bzl", "validate_tool_exists")
load("//toolchains:tool_registry.bzl", "tool_registry")

# Platforms where meld native binaries are published. Meld has no wasm fallback
# (unlike loom/wsc), so meld_fuse is unusable on other platforms until upstream
# publishes binaries for them.
_SUPPORTED_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
]

def _meld_toolchain_impl(ctx):
    """Implementation of meld_toolchain rule."""
    return [platform_common.ToolchainInfo(
        meld = ctx.file.meld,
    )]

meld_toolchain = rule(
    implementation = _meld_toolchain_impl,
    attrs = {
        "meld": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "meld binary for component fusion",
        ),
    },
    doc = "Declares a Meld toolchain for WebAssembly component fusion",
)

_STUB_BUILD = '''"""Meld toolchain stub: unsupported platform.

Meld has no native binary for this host, so we register a toolchain that is
marked incompatible with any target. Toolchain resolution for meld_fuse
targets will fail cleanly on this platform; builds that never touch
meld_fuse are unaffected.
"""

load("@rules_wasm_component//toolchains:meld_toolchain.bzl", "meld_toolchain")

package(default_visibility = ["//visibility:public"])

# Dummy placeholder, produced by the repository rule. Never executed because
# the toolchain below is gated as @platforms//:incompatible.
exports_files(["meld_stub"])

meld_toolchain(
    name = "meld_toolchain_impl",
    meld = "meld_stub",
)

toolchain(
    name = "meld_toolchain",
    target_compatible_with = ["@platforms//:incompatible"],
    toolchain = ":meld_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:meld_toolchain_type",
)
'''

def _meld_repository_impl(repository_ctx):
    """Download meld native binary and create toolchain repository."""
    platform = tool_registry.detect_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Unsupported platform: emit a stub so module resolution doesn't fail
    # on Windows/other hosts. meld_fuse targets simply won't be buildable.
    if platform not in _SUPPORTED_PLATFORMS or not validate_tool_exists(repository_ctx, "meld", version, platform):
        print("Meld: no native binary for platform {} (version {}); emitting stub".format(platform, version))
        # Create a placeholder file so the meld_toolchain rule's single-file
        # attribute resolves during loading. The toolchain is never selected
        # (target_compatible_with = @platforms//:incompatible) so this file
        # is never actually invoked.
        repository_ctx.file("meld_stub", content = "", executable = True)
        repository_ctx.file("BUILD.bazel", _STUB_BUILD)
        return

    print("Setting up meld {} for platform {}".format(version, platform))

    # Download meld (bare binary, no extraction)
    tool_registry.download(
        repository_ctx,
        "meld",
        version,
        platform,
        output_name = "meld",
    )

    repository_ctx.file("BUILD.bazel", '''"""Meld toolchain repository"""

load("@rules_wasm_component//toolchains:meld_toolchain.bzl", "meld_toolchain")

package(default_visibility = ["//visibility:public"])

meld_toolchain(
    name = "meld_toolchain_impl",
    meld = ":meld",
)

toolchain(
    name = "meld_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":meld_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:meld_toolchain_type",
)
''')

meld_repository = repository_rule(
    implementation = _meld_repository_impl,
    attrs = {
        "version": attr.string(
            default = "0.10.0",
            doc = "Meld version to download",
        ),
    },
    doc = "Downloads meld and creates a toolchain repository",
)
