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
    tools = ["rivet", "synth", "wsc"],
)
use_repo(varve, "varve_tools")
# then depend on @varve_tools//:synth etc.
```

Trust model: the single trust-on-first-use root is the sha256 pin of the
varve binary in `varve_checksums.json` (transcribed from varve's
cosign-verified release sums). Every tool byte after that is accepted or
refused by varve's signature chain — this extension cannot relax it, and
swapping the `registry` (mirror, air gap) changes availability only.

Relation to the checksum registries in `//checksums`: those remain for
consumers without varve; `varve export-bazel` (varve ≥ 0.9.0) can compile
them from a verified layer so their hashes are signature-anchored rather
than trust-on-first-use.
