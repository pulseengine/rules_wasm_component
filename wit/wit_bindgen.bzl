"""WIT binding generation rule"""

load("//providers:providers.bzl", "WitInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

def _wit_bindgen_impl(ctx):
    """Implementation of wit_bindgen rule"""
    
    # Get WIT info from input
    wit_info = ctx.attr.wit[WitInfo]
    
    # Determine output file/directory based on language
    if ctx.attr.language == "rust":
        out_file = ctx.actions.declare_file(ctx.label.name + "_bindings.rs")
    elif ctx.attr.language == "c":
        # C generates multiple files
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_bindings")
        out_file = out_dir
    else:
        fail("Unsupported language: " + ctx.attr.language)
    
    # Get wit-bindgen from toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wit_bindgen = toolchain.wit_bindgen
    
    # Build command arguments
    args = ctx.actions.args()
    args.add(ctx.attr.language)
    
    # Add WIT files
    for wit_file in wit_info.wit_files.to_list():
        args.add("--wit", wit_file)
    
    # Add output location
    if ctx.attr.language == "rust":
        args.add("--out-dir", paths.dirname(out_file.path))
    else:
        args.add("--out-dir", out_file.path)
    
    # Add world if specified
    if wit_info.world_name:
        args.add("--world", wit_info.world_name)
    
    # Add additional options
    if ctx.attr.options:
        args.add_all(ctx.attr.options)
    
    # Run wit-bindgen
    ctx.actions.run(
        executable = wit_bindgen,
        arguments = [args],
        inputs = depset(transitive = [wit_info.wit_files, wit_info.wit_deps]),
        outputs = [out_file],
        mnemonic = "WitBindgen",
        progress_message = "Generating {} bindings for {}".format(
            ctx.attr.language,
            ctx.label,
        ),
    )
    
    return [DefaultInfo(files = depset([out_file]))]

wit_bindgen = rule(
    implementation = _wit_bindgen_impl,
    attrs = {
        "wit": attr.label(
            providers = [WitInfo],
            mandatory = True,
            doc = "WIT library to generate bindings for",
        ),
        "language": attr.string(
            values = ["rust", "c", "go", "python"],
            default = "rust",
            doc = "Target language for bindings",
        ),
        "options": attr.string_list(
            doc = "Additional options to pass to wit-bindgen",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Generates language bindings from WIT files.
    
    This rule uses wit-bindgen to generate language-specific bindings
    from WIT interface definitions.
    
    Example:
        wit_bindgen(
            name = "my_bindings",
            wit = ":my_interfaces",
            language = "rust",
        )
    """,
)