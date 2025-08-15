load("//wasm:defs.bzl", "wasm_sign")

# Test basic signing to debug the issue
wasm_sign(
    name = "test_basic_signing",
    component = "//examples/basic:hello_component",
    keys = ":oci_signing_keys",
    openssh_format = True,
)
