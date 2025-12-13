"""Bazel module extensions for WebAssembly tool source repositories"""

def _git_repos_impl(module_ctx):
    """Extension implementation for git repositories"""

    # Track which repos we've created to avoid duplicates
    repos_created = {}

    for mod in module_ctx.modules:
        for call in mod.tags.wasm_tools:
            if "wasm_tools_src" not in repos_created:
                module_ctx.download_and_extract(
                    name = "wasm_tools_src",
                    url = "https://github.com/bytecodealliance/wasm-tools/archive/refs/tags/{}.tar.gz".format(call.tag),
                    strip_prefix = "wasm-tools-{}".format(call.tag.lstrip("v")),
                )
                repos_created["wasm_tools_src"] = True

        for call in mod.tags.wit_bindgen:
            if "wit_bindgen_src" not in repos_created:
                module_ctx.download_and_extract(
                    name = "wit_bindgen_src",
                    url = "https://github.com/bytecodealliance/wit-bindgen/archive/refs/tags/{}.tar.gz".format(call.tag),
                    strip_prefix = "wit-bindgen-{}".format(call.tag.lstrip("v")),
                )
                repos_created["wit_bindgen_src"] = True

        # Note: wizer removed - now part of wasmtime v39.0.0+

        for call in mod.tags.wac:
            if "wac_src" not in repos_created:
                module_ctx.download_and_extract(
                    name = "wac_src",
                    url = "https://github.com/bytecodealliance/wac/archive/refs/tags/{}.tar.gz".format(call.tag),
                    strip_prefix = "wac-{}".format(call.tag.lstrip("v")),
                )
                repos_created["wac_src"] = True

        for call in mod.tags.wasmtime:
            if "wasmtime_src" not in repos_created:
                module_ctx.download_and_extract(
                    name = "wasmtime_src",
                    url = "https://github.com/bytecodealliance/wasmtime/archive/refs/tags/{}.tar.gz".format(call.tag),
                    strip_prefix = "wasmtime-{}".format(call.tag.lstrip("v")),
                )
                repos_created["wasmtime_src"] = True

# Tag schemas for each tool
_wasm_tools_tag = tag_class(attrs = {
    "tag": attr.string(mandatory = True),
})

_wit_bindgen_tag = tag_class(attrs = {
    "tag": attr.string(mandatory = True),
})

_wac_tag = tag_class(attrs = {
    "tag": attr.string(mandatory = True),
})

_wasmtime_tag = tag_class(attrs = {
    "tag": attr.string(mandatory = True),
})

# Extension definition
git_repos = module_extension(
    implementation = _git_repos_impl,
    tag_classes = {
        "wasm_tools": _wasm_tools_tag,
        "wit_bindgen": _wit_bindgen_tag,
        "wac": _wac_tag,
        "wasmtime": _wasmtime_tag,
    },
)
