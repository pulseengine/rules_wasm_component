"""Module extension for hermetic WebAssembly tools via pre-built binaries

This extension downloads pre-built binaries for WebAssembly tools using
verified checksums for truly hermetic builds without external dependencies.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def _wasm_hermetic_impl(module_ctx):
    """Implementation for wasm_hermetic module extension"""

    # wasm-tools hermetic binary (linux_amd64 for now)
    http_archive(
        name = "wasm_tools_hermetic",
        urls = [
            "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-x86_64-linux.tar.gz",
        ],
        strip_prefix = "wasm-tools-1.235.0-x86_64-linux",
        sha256 = "4c44bc776aadbbce4eedc90c6a07c966a54b375f8f36a26fd178cea9b419f584",
        build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "bin",
    srcs = glob(["wasm-*"]),
)
""",
    )

    # wit-bindgen hermetic binary (linux_amd64 for now)
    http_archive(
        name = "wit_bindgen_hermetic",
        urls = [
            "https://github.com/bytecodealliance/wit-bindgen/releases/download/v0.43.0/wit-bindgen-0.43.0-x86_64-linux.tar.gz",
        ],
        strip_prefix = "wit-bindgen-0.43.0-x86_64-linux",
        sha256 = "cb6b0eab0f8abbf97097cde9f0ab7e44ae07bf769c718029882b16344a7cda64",
        build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "bin",
    srcs = glob(["wit-bindgen*"]),
)
""",
    )

    # wasmtime hermetic binary (linux_amd64 for now)
    http_archive(
        name = "wasmtime_hermetic",
        urls = [
            "https://github.com/bytecodealliance/wasmtime/releases/download/v35.0.0/wasmtime-v35.0.0-x86_64-linux.tar.xz",
        ],
        strip_prefix = "wasmtime-v35.0.0-x86_64-linux",
        sha256 = "e3d2aae710a5cef548ab13f7e4ed23adc4fa1e9b4797049f4459320f32224011",
        build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "bin",
    srcs = glob(["wasmtime*"]),
)
""",
    )

    # wac hermetic binary (linux_amd64 for now) - single binary download
    http_file(
        name = "wac_hermetic",
        urls = [
            "https://github.com/bytecodealliance/wac/releases/download/v0.7.0/wac-cli-x86_64-unknown-linux-musl",
        ],
        sha256 = "dd734c4b049287b599a3f8c553325307687a17d070290907e3d5bbe481b89cc6",
        executable = True,
        downloaded_file_path = "wac",
    )

    # wkg hermetic binary (linux_amd64 for now) - single binary download
    http_file(
        name = "wkg_hermetic",
        urls = [
            "https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v0.11.0/wkg-x86_64-unknown-linux-gnu",
        ],
        sha256 = "e3bec9add5a739e99ee18503ace07d474ce185d3b552763785889b565cdcf9f2",
        executable = True,
        downloaded_file_path = "wkg",
    )

_register_tag = tag_class()

wasm_hermetic = module_extension(
    implementation = _wasm_hermetic_impl,
    tag_classes = {
        "register": _register_tag,
    },
)
