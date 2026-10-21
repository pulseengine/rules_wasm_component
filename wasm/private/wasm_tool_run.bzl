"""SPIKE: hermetic tool execution under wasmtime via a single preopened root.

Proof-of-concept for running a tool compiled to WebAssembly as a hermetic Bazel
action, mapping files in/out through ONE preopened directory
(`wasmtime run --dir root::/`) rather than a list of per-file/absolute-path
preopens — the model standardized by WebAssembly/wasi-testsuite#264.

KEY FINDING (see SPIKE.md):
  - The single-root model itself works perfectly: a guest given one preopened
    root sees a normal filesystem and cannot escape it (hermeticity is the
    intersection of Bazel's sandbox and WASI's deny-by-default capabilities —
    the guest cannot even name a host-absolute path).
  - BUT Bazel stages an action's declared inputs as *symlinks pointing outside*
    the sandbox, and WASI refuses to traverse a symlink that escapes a preopen
    (errno 63 = ENOTCAPABLE). So the inputs must be materialized as REAL files
    inside the preopened root. The preopen directory may itself be a symlink
    (wasmtime canonicalizes it when it opens the preopen); only files traversed
    *inside* the guest must not escape.
  - This is exactly why the older multi-preopen / absolute-host-path approach
    fought Bazel: you cannot hand WASI Bazel's relocatable symlink farm. One
    materialized root + guest-absolute paths is the clean shape.

SPIKE-ONLY: the input staging below uses run_shell (cp) for brevity. Production
should replace it with a hermetic copy (aspect bazel-lib `copy_to_directory`
into a TreeArtifact, or a small Rust launcher) per RULE #1 — no shell. The
wasmtime invocation and the single-root model are the parts being validated.
"""

def _wasm_tool_run_impl(ctx):
    wasmtime = ctx.toolchains["@rules_wasm_component//toolchains:wasmtime_toolchain_type"].wasmtime

    out = ctx.actions.declare_file(ctx.attr.out)
    root = "_wasm_root"

    # Stage declared inputs as REAL files (cp -L dereferences Bazel's staging
    # symlinks) into one root, run wasmtime mapping that root as the single
    # guest "/", then collect the single output the tool wrote to /out.
    copies = "\n".join([
        'cp -L "{src}" "{root}/{base}"'.format(src = s.path, root = root, base = s.basename)
        for s in ctx.files.srcs
    ])
    guest_inputs = " ".join(['"/{}"'.format(s.basename) for s in ctx.files.srcs])
    extra = " ".join(['"{}"'.format(a) for a in ctx.attr.extra_args])

    command = """set -e
mkdir -p "{root}"
{copies}
"{wasmtime}" run --dir "{root}::/" "{tool}" {inputs} "/out" {extra}
cp "{root}/out" "{out}"
""".format(
        root = root,
        copies = copies,
        wasmtime = wasmtime.path,
        tool = ctx.file.tool.path,
        inputs = guest_inputs,
        extra = extra,
        out = out.path,
    )

    ctx.actions.run_shell(
        command = command,
        inputs = ctx.files.srcs + [ctx.file.tool],
        outputs = [out],
        tools = [wasmtime],
        mnemonic = "WasmToolRun",
        progress_message = "Running %s under wasmtime (single-root hermetic) -> %s" % (
            ctx.file.tool.short_path,
            out.short_path,
        ),
    )

    return [DefaultInfo(files = depset([out]))]

wasm_tool_run = rule(
    implementation = _wasm_tool_run_impl,
    attrs = {
        "tool": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "WebAssembly tool (wasi:cli/command) to execute with wasmtime. " +
                  "rust_wasm_binary names its output without a .wasm extension.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Declared input files, materialized as real files inside the " +
                  "single preopened root; the guest sees them at /<basename> " +
                  "and nothing else.",
        ),
        "out": attr.string(
            mandatory = True,
            doc = "Name of the single output file the tool writes (guest /out).",
        ),
        "extra_args": attr.string_list(
            doc = "Extra literal argv appended after the input/output paths.",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
    doc = "SPIKE: run a wasm tool hermetically via a single preopened root.",
)
