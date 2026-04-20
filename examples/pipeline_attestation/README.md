# Pipeline attestation example

End-to-end demonstration of the PulseEngine attestation surface:

```
rust_wasm_component_bindgen  ->  wasm_sign  ->  wasm_attest
                                                    |
                            wasm_show_chain  <-----+
                            wasm_verify_chain <----+
```

## Targets

| Target | Rule | Output |
|--------|------|--------|
| `:greeter_component` | `rust_wasm_component_bindgen` | Signed-free WASM component |
| `:example_keys` | `wasm_keygen` | Ed25519 key pair (compact format) |
| `:greeter_signed` | `wasm_sign` | Component with embedded signature |
| `:greeter_attested` | `wasm_attest` | Signed component + transformation attestation |
| `:greeter_chain` | `wasm_show_chain` | Chain as JSON (CI-friendly artifact) |
| `:greeter_chain_verified` | `wasm_verify_chain` | Success marker, fails the build on policy/chain error |
| `:all_pipeline_outputs` | `filegroup` | Convenience aggregate |

## Build it

```sh
bazel build //examples/pipeline_attestation:all_pipeline_outputs
```

Expected output includes a success message from `wasm_verify_chain`:

```
✓ Transformation chain is valid
Transformation stages: 1
Tools used: wasmsign2
```

And a JSON chain (`greeter_chain.json`) with one attestation entry recording
input hash, output hash, tool name/version, and timestamp.

## Why `wasm_attest` here rather than `meld_fuse` or `wasm_optimize`

- **`meld_fuse`** produces meaningful chains but requires two or more
  components with compatible component-model interfaces — an end-to-end
  fusion demo is more than this example wants to set up.
- **`wasm_optimize` (loom)** has a pending WASI path-resolution issue (see
  the `TODO` in `wasm/private/wasm_optimize.bzl`) so it is not wired into
  this example yet.

`wasm_attest` is the attestation escape hatch for arbitrary transformations
and is sufficient to demonstrate the full `sign -> attest -> verify -> show`
surface against a single component. Once `wasm_optimize` and `meld_fuse`
self-attest reliably end-to-end, follow-up examples can chain them.
