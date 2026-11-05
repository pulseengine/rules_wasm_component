# Spike: hermetic tool execution under wasmtime via a single preopened root

**Question (from the wasi-testsuite#264 discussion):** now that WASI is moving to
a single-root filesystem model, can we map the Bazel-hermetic file model onto
wasmtime and call tools-as-wasm hermetically — the thing the older
multi-preopen / absolute-host-path approach couldn't do cleanly?

**Answer: yes, the single-root model works — with one Bazel-specific caveat that
this spike pins down exactly.**

## What this spike contains

- `transform.rs` — a tiny WASI command (built to `wasm32-wasip2` via
  `rust_wasm_binary`) that reads an input file, uppercases it, writes an output
  file, and **probes hermeticity**: it tries to read `/etc/hostname` and
  `/etc/passwd` and exits non-zero if either succeeds.
- `//wasm/private:wasm_tool_run.bzl` — an experimental rule that runs the tool
  as a hermetic Bazel action, mapping inputs/outputs through **one** preopened
  root (`wasmtime run --dir root::/`).
- `transform_output_test` — a `diff_test` that is green only if the tool read +
  transformed + wrote through the single root **and** the hermeticity probe was
  denied.

Run it: `bazel test //test/spike_wasmtime_hermetic:all`

## Findings

### 1. The single-root model works, and hermeticity is free

Given one preopened root, the guest sees a normal filesystem rooted at `/` and
**cannot escape it**. There is no WASI way to name a host-absolute path; the only
thing visible is what is inside the preopen. Combined with Bazel's sandbox (which
already contains only the declared inputs), hermeticity is the intersection of
two independent deny-by-default systems. The probe reading `/etc/hostname` is
denied every run — `sandbox confirmed` in the action log.

### 2. The real obstacle: Bazel stages inputs as symlinks that escape the preopen

The first attempt — preopen the action's execroot directly (`--dir .::/`) and
pass guest-absolute paths — failed with:

```
cannot read /test/.../sample.txt: Operation not permitted (os error 63)
```

**errno 63 is WASI `ENOTCAPABLE`**, not a generic error. Root cause, confirmed
two ways:

- A hand-made symlink pointing outside the preopen reproduces the identical
  `ENOTCAPABLE`.
- Bazel stages the declared input in the sandbox as a symlink pointing *out* of
  the sandbox execroot:
  `sandbox/.../execroot/_main/.../sample.txt -> /private/var/tmp/.../execroot/_main/.../sample.txt`

WASI refuses to traverse a symlink that escapes a preopen. wasmtime has **no
flag** to relax this (`--dir` takes only `HOST[::GUEST]`; no follow-symlinks /
permissions option).

### 3. The fix: materialize inputs as real files inside the root

The preopen **directory** may itself be a symlink — wasmtime canonicalizes it
when it opens the preopen at startup. Only files traversed *inside the guest*
must not escape. So copying the declared inputs into one real root directory and
preopening that makes everything work (this spike does the copy with `cp -L`;
see "Production path"). The module file the loader reads is fine either way —
only WASI guest filesystem access is capability-checked.

### 4. Why the old approach couldn't do this

The previous model enumerated individual host **absolute** preopens
(`--dir /abs/a --dir /abs/b …`) plus a fragile argv convention naming the first
preopen. That fights Bazel head-on: Bazel paths are relocatable and staged as a
symlink farm, so there were no stable host-absolute paths to hand WASI, and any
that were handed in pointed at escaping symlinks. The single-root direction
(wasi-testsuite#264) replaces all of that with **one** root + guest-absolute
paths — which maps cleanly onto "one materialized sandbox directory."

## Efficiency

This spike validates *correctness/hermeticity*, not yet speed. The two known
startup costs and their existing levers in this repo:

- **JIT compile per invocation** → AOT-compile the tool to `.cwasm`
  (`wasm_precompile` / `--allow-precompiled`) so wasmtime loads precompiled code.
- **Guest init per invocation** → Wizer pre-initialization (already supported via
  the wasmtime toolchain) snapshots post-init state.

A real benchmark (native tool vs JIT wasm vs AOT+wizer wasm, over N invocations)
is the next step before claiming "efficient" with a number.

## Production path (not done here — spike scope)

1. Replace the `cp` staging with a hermetic copy into a `TreeArtifact`
   (aspect bazel-lib `copy_to_directory`) or a small Rust launcher — **no shell**
   per RULE #1. The shell `cp` here is the one spike shortcut.
2. Support multiple / structured outputs (declare a `TreeArtifact` the tool
   writes into) instead of a single `/out`.
3. AOT + Wizer wiring and a benchmark target.
4. Decide the input path convention (flat `/basename` here vs. mirrored tree).

## Verdict

The single-root filesystem direction makes hermetic tool-as-wasm execution under
wasmtime genuinely viable for the Bazel model — the capability was always there,
but the ergonomics now line up. The one thing a production rule MUST handle is
materializing declared inputs as real files in the root (Bazel's symlink staging
+ WASI's no-escape rule = `ENOTCAPABLE` otherwise). That is the concrete result
this spike was built to find.
