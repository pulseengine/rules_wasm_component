# Copyright 2026 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

"""Loom toolchain: native binary for WebAssembly component optimization.

loom optimizes a WebAssembly component (constant folding, CSE, inlining, DCE,
fused-component passes, optional Z3 verification). As of v1.x loom is
distributed as native per-OS binaries (the v0.x `loom.wasm` component was
dropped), so wasm_optimize runs the native binary directly instead of running
loom.wasm under wasmtime. Mirrors toolchains/meld_toolchain.bzl, but loom ships
tarballs (extracted) rather than a bare binary.
"""

load("//checksums:registry.bzl", "validate_tool_exists")
load("//toolchains:tool_registry.bzl", "tool_registry")

# Platforms where loom native binaries are downloaded + extracted here. loom
# also ships a Windows binary (loom.exe), but that path is not wired yet
# (binary-name differs); Windows gets the stub for now (see #512 follow-up).
_SUPPORTED_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
]

def _loom_toolchain_impl(ctx):
    """Implementation of loom_toolchain rule."""
    return [platform_common.ToolchainInfo(
        loom = ctx.file.loom,
    )]

loom_toolchain = rule(
    implementation = _loom_toolchain_impl,
    attrs = {
        "loom": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "loom binary for component optimization",
        ),
    },
    doc = "Declares a Loom toolchain for WebAssembly component optimization",
)

_STUB_BUILD = '''"""Loom toolchain stub: unsupported platform.

loom has no wired native binary for this host, so we register a toolchain that
is marked incompatible with any target. Toolchain resolution for wasm_optimize
targets fails cleanly here; builds that never touch wasm_optimize are unaffected.
"""

load("@rules_wasm_component//toolchains:loom_toolchain.bzl", "loom_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["loom_stub"])

loom_toolchain(
    name = "loom_toolchain_impl",
    loom = "loom_stub",
)

toolchain(
    name = "loom_toolchain",
    target_compatible_with = ["@platforms//:incompatible"],
    toolchain = ":loom_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:loom_toolchain_type",
)
'''

def _loom_repository_impl(repository_ctx):
    """Download + extract the loom native binary and create a toolchain repo."""
    platform = tool_registry.detect_platform(repository_ctx)
    version = repository_ctx.attr.version

    if platform not in _SUPPORTED_PLATFORMS or not validate_tool_exists(repository_ctx, "loom", version, platform):
        print("Loom: no wired native binary for platform {} (version {}); emitting stub".format(platform, version))
        repository_ctx.file("loom_stub", content = "", executable = True)
        repository_ctx.file("BUILD.bazel", _STUB_BUILD)
        return

    print("Setting up loom {} for platform {}".format(version, platform))

    # loom ships a tarball containing ./loom; tool_registry extracts it (the
    # 1.1.14 registry entries have no `binary: true`) and returns the binary
    # path. strip_prefix is "" (flat archive) — see _calculate_strip_prefix.
    tool_registry.download(
        repository_ctx,
        "loom",
        version,
        platform,
    )

    repository_ctx.file("BUILD.bazel", '''"""Loom toolchain repository"""

load("@rules_wasm_component//toolchains:loom_toolchain.bzl", "loom_toolchain")

package(default_visibility = ["//visibility:public"])

loom_toolchain(
    name = "loom_toolchain_impl",
    loom = ":loom",
)

toolchain(
    name = "loom_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":loom_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:loom_toolchain_type",
)
''')

loom_repository = repository_rule(
    implementation = _loom_repository_impl,
    attrs = {
        "version": attr.string(
            default = "1.1.14",
            doc = "Loom version to download",
        ),
    },
    doc = "Downloads loom and creates a toolchain repository",
)
