"""varve_resolution_test: every varve-carried tool resolves from the varve layer.

FEAT-004 says loom, meld, spar, synth, witness, wasm-tools, wkg and
wit-bindgen-wrpc come from varve's covalent realm on linux and macOS. A green
build does not show that: toolchain resolution takes the first matching
registration, and a registration-order mistake in MODULE.bazel would let the
per-tool fallback win silently (see //varve/toolchains:BUILD.bazel). This test
reads each resolved toolchain's tool file and fails unless it is owned by the
varve tools repository.
"""

# toolchain type -> ToolchainInfo field holding the tool file
_VARVE_TOOLS = {
    "//toolchains:loom_toolchain_type": ["loom"],
    "//toolchains:meld_toolchain_type": ["meld"],
    "//toolchains:spar_toolchain_type": ["spar"],
    "//toolchains:synth_toolchain_type": ["synth"],
    "//toolchains:witness_toolchain_type": ["witness"],
    "//toolchains:wasm_tools_toolchain_type": ["wasm_tools", "wit_bindgen_wrpc"],
    "//toolchains:wkg_toolchain_type": ["wkg"],
}

def _impl(ctx):
    failures = []
    checked = []
    for toolchain_type, fields in _VARVE_TOOLS.items():
        info = ctx.toolchains[toolchain_type]
        for field in fields:
            f = getattr(info, field, None)
            if f == None:
                failures.append("%s: %s is unset" % (toolchain_type, field))
                continue
            repo = f.owner.repo_name if f.owner else ""
            checked.append("%s.%s <- %s" % (toolchain_type, field, f.owner))
            if ctx.attr.repo_marker not in repo:
                failures.append("%s.%s resolved to %s, not the varve layer" % (toolchain_type, field, f.owner))

    lines = ["#!/bin/sh"]
    for c in checked:
        lines.append("echo 'checked: %s'" % c)
    if failures:
        for msg in failures:
            lines.append("echo 'FAIL: %s' >&2" % msg)
        lines.append("exit 1")
    else:
        lines.append("echo 'all %d varve-carried tools resolve from the varve layer'" % len(checked))
        lines.append("exit 0")

    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(script, "\n".join(lines) + "\n", is_executable = True)
    return [DefaultInfo(executable = script)]

varve_resolution_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "repo_marker": attr.string(
            default = "varve_tools",
            doc = "Substring of the canonical repository name that owns varve-provided tools.",
        ),
    },
    toolchains = list(_VARVE_TOOLS.keys()),
)
