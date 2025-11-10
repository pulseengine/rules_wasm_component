"""Symmetric WIT binding generation rule using cpetig's fork"""

load("//providers:providers.bzl", "WitInfo")

def _to_snake_case(name):
    """Convert a name to snake_case (matching wit-bindgen's Rust backend logic)"""

    # Replace hyphens with underscores and convert to lowercase
    return name.replace("-", "_").lower()

def _symmetric_wit_bindgen_impl(ctx):
    """Implementation of symmetric wit_bindgen rule"""

    # Get WIT info from input
    wit_info = ctx.attr.wit[WitInfo]

    # Determine output file/directory based on language
    if ctx.attr.language == "rust":
        # wit-bindgen for Rust generates filename as: world_name.to_snake_case() + ".rs"
        # Source: bytecodealliance/wit-bindgen/crates/rust/src/lib.rs - fn finish()
        # world_name is now mandatory in wit_library, so this is always predictable
        rust_filename = _to_snake_case(wit_info.world_name) + ".rs"
        out_file = ctx.actions.declare_file(rust_filename)
    elif ctx.attr.language == "c":
        # C generates multiple files
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_bindings")
        out_file = out_dir
    else:
        fail("Unsupported language: " + ctx.attr.language)

    # Get wit-bindgen from symmetric toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:symmetric_wit_bindgen_toolchain_type"]
    wit_bindgen = toolchain.wit_bindgen_symmetric

    # Get the main WIT library directory which contains the deps structure
    wit_library_dir = None
    if hasattr(ctx.attr.wit[DefaultInfo], "files"):
        for file in ctx.attr.wit[DefaultInfo].files.to_list():
            if file.is_directory:
                wit_library_dir = file
                break

    # Build command arguments for symmetric wit-bindgen CLI
    cmd_args = [ctx.attr.language]

    # Add world if specified using --world syntax
    if wit_info.world_name:
        cmd_args.extend(["--world", wit_info.world_name])

    # Add additional options
    if ctx.attr.options:
        cmd_args.extend(ctx.attr.options)

    # For Rust, configure for symmetric mode
    if ctx.attr.language == "rust":
        # Symmetric mode: Add symmetric-specific options
        cmd_args.extend(["--symmetric"])
        if ctx.attr.invert_direction:
            cmd_args.extend(["--invert-direction"])

        # Use symmetric runtime path
        cmd_args.extend(["--runtime-path", "crate::wit_bindgen::rt"])

    # Add WIT files at the end (positional argument)
    wit_file_args = []
    for wit_file in wit_info.wit_files.to_list():
        wit_file_args.append(wit_file.path)
    cmd_args.extend(wit_file_args)

    # Create output directory for Rust to handle unpredictable filenames
    if ctx.attr.language == "rust":
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_output")

        # Use the WIT library directory directly - no temp directories
        if wit_library_dir:
            # Run wit-bindgen directly on the WIT library directory
            # The wit_library already contains the proper structure with deps/

            # Check if we have external dependencies and add --generate-all if needed
            bindgen_args = cmd_args[:-len(wit_file_args)]
            if wit_info.wit_deps and len(wit_info.wit_deps.to_list()) > 0:
                # Add --generate-all to handle external dependencies automatically
                bindgen_args.append("--generate-all")

            bindgen_args.extend([wit_library_dir.path, "--out-dir", out_dir.path])

            ctx.actions.run(
                executable = wit_bindgen,
                arguments = bindgen_args,
                inputs = depset(
                    direct = [wit_library_dir],
                    transitive = [wit_info.wit_files, wit_info.wit_deps],
                ),
                outputs = [out_dir],
                mnemonic = "SymmetricWitBindgen",
                progress_message = "Generating symmetric {} bindings for {}".format(
                    ctx.attr.language,
                    ctx.label,
                ),
            )

            # Extract the generated .rs file from output directory
            # wit-bindgen creates a predictable filename: world_name.to_snake_case() + ".rs"
            # Since world is now mandatory, we always know the exact filename
            # Use file_ops component for cross-platform file copying
            source_path = out_dir.path + "/" + rust_filename

            # Build JSON config for file_ops
            config_file = ctx.actions.declare_file(ctx.label.name + "_extract_config.json")
            ctx.actions.write(
                output = config_file,
                content = json.encode({
                    "workspace_dir": ".",
                    "operations": [{
                        "type": "copy_file",
                        "src_path": source_path,
                        "dest_path": out_file.path,
                    }],
                }),
            )

            # Get file_ops tool from toolchain
            file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
            file_ops_tool = file_ops_toolchain.file_ops_component

            # Execute cross-platform file copy
            ctx.actions.run(
                executable = file_ops_tool,
                arguments = [config_file.path],
                inputs = [out_dir, config_file],
                outputs = [out_file],
                mnemonic = "ExtractSymmetricBinding",
                progress_message = "Extracting {} from symmetric wit-bindgen output".format(rust_filename),
            )
        else:
            # No dependencies - run wit-bindgen directly on WIT files
            ctx.actions.run(
                executable = wit_bindgen,
                arguments = cmd_args + ["--out-dir", out_dir.path],
                inputs = wit_info.wit_files,
                outputs = [out_file, out_dir],
                mnemonic = "SymmetricWitBindgen",
                progress_message = "Generating symmetric {} bindings for {}".format(
                    ctx.attr.language,
                    ctx.label,
                ),
            )
    else:
        # For other languages (not yet supported with symmetric)
        fail("Symmetric mode currently only supports Rust language")

    return [DefaultInfo(files = depset([out_file]))]

symmetric_wit_bindgen = rule(
    implementation = _symmetric_wit_bindgen_impl,
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
        "invert_direction": attr.bool(
            default = False,
            doc = "Invert direction for symmetric interfaces",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:symmetric_wit_bindgen_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Generates symmetric language bindings from WIT files using cpetig's fork.

    This rule uses the symmetric wit-bindgen fork to generate language-specific bindings
    that can work for both native and WASM execution from the same source code.

    Example:
        symmetric_wit_bindgen(
            name = "my_symmetric_bindings",
            wit = ":my_interfaces",
            language = "rust",
        )
    """,
)
