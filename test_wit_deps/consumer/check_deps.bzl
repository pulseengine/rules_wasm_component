load("@rules_wasm_component//wit:wit_deps_check.bzl", "wit_deps_check")

wit_deps_check(
    name = "check_deps",
    wit_file = "consumer.wit",
)