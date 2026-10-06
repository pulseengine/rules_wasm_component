"""Shared macro for //varve/toolchains:BUILD.bazel — see that file's docstring
for why every varve-backed toolchain here needs this exact linux/macos split
(varve ships no Windows binary) and why registration order in MODULE.bazel
matters.
"""

def varve_toolchain_pair(name, rule, toolchain_type, **kwargs):
    """Declares `<name>_impl` plus linux and macos `toolchain()` registrations for it."""
    rule(name = name + "_impl", **kwargs)
    for os in ("linux", "macos"):
        native.toolchain(
            name = name + "_" + os,
            exec_compatible_with = ["@platforms//os:" + os],
            target_compatible_with = [],
            toolchain = ":" + name + "_impl",
            toolchain_type = toolchain_type,
        )
