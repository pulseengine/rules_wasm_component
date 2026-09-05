# varve module extension (EXPERIMENTAL)

Bazel consumes [varve](https://github.com/pulseengine/varve) — it does not
reimplement it. One `varve.toml` pin governs the developer terminal (shims)
AND the Bazel build; the layer is signature-verified (DSSE against the
pinned trust root) and anti-rollback-protected by varve itself, inside a
hermetic, repo-local root that Bazel invalidates when the pin or trust
root changes.

```starlark
# MODULE.bazel
varve = use_extension("@rules_wasm_component//varve:varve.bzl", "varve")
varve.configure(
    pin = "//:varve.toml",
    trust_root = "//:trust-roots/rolling.pub",
    tools = ["loom", "meld", "rivet", "spar", "synth", "witness", "wsc"],
)
use_repo(varve, "varve_tools")
# then depend on @varve_tools//:synth etc.
```

As of layer `2026.09.0`, that covers every PulseEngine tool this repo's own
`checksum_updater` hand-manages today (`checksums/tools/{loom,meld,spar,synth,
witness,wsc}.json`) plus `rivet`, which isn't tracked there at all. See
`examples/varve_extension` for a working `varve.configure` pulling all six.

Trust model: the single trust-on-first-use root is the sha256 pin of the
varve binary in `varve_checksums.json` (transcribed from varve's
cosign-verified release sums). Every tool byte after that is accepted or
refused by varve's signature chain — this extension cannot relax it, and
swapping the `registry` (mirror, air gap) changes availability only.

Environment: `varve verify` also checks that the pinned layer's tools match
what the invoking developer's shell would run (`REQ-SHADOW-001`, no opt-out —
a deliberate varve safety feature, not a bug). That check is about a human's
interactive shell and has no meaning inside a hermetic Bazel repository rule,
which has no such shell — so this extension runs varve with a minimal,
ambient-free `PATH` (standard system directories only), rather than the
`repository_ctx.execute()` default of inheriting the invoking developer's full
environment. Without this, anyone who also has one of these tools installed
outside Bazel (plausible — they're the PulseEngine team's own CLIs) would hit
a shadow-check failure unrelated to whether the pinned layer is trustworthy.
Verified locally: without the fix, a machine with `loom`/`meld`/`spar`/`synth`
on `PATH` via `cargo install` fails every build; with it, the same machine
builds clean.

Relation to the checksum registries in `//checksums`: those remain for
consumers without varve; `varve export-bazel` (varve ≥ 0.9.0) can compile
them from a verified layer so their hashes are signature-anchored rather
than trust-on-first-use. Given the tool-coverage overlap above, retiring the
hand-maintained entries for the six tools varve now covers — once this
extension graduates past EXPERIMENTAL — is a real reduction in
`checksum_updater`'s surface, not just a parallel path; tracked as a
follow-up, not done in this change.
