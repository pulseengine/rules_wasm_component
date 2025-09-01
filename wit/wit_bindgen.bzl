"""WIT binding generation rule with interface mapping support"""

load("//providers:providers.bzl", "WitInfo")

def _build_with_args(with_mappings):
    """Build --with arguments from with_mappings dict"""
    if not with_mappings:
        return []

    # Convert dict to comma-separated k=v pairs
    mappings = []
    for key, value in with_mappings.items():
        mappings.append("{}={}".format(key, value))

    return ["--with", ",".join(mappings)]

def _build_derive_args(additional_derives):
    """Build --additional-derive-attributes arguments"""
    args = []
    for derive in additional_derives:
        args.extend(["--additional-derive-attributes", derive])
    return args

def _build_async_args(async_interfaces):
    """Build --async arguments for async interface configuration"""
    args = []
    for async_interface in async_interfaces:
        args.extend(["--async", async_interface])
    return args

def _wit_bindgen_impl(ctx):
    """Implementation of wit_bindgen rule"""

    # Get WIT info from input
    wit_info = ctx.attr.wit[WitInfo]

    # Determine output file/directory based on language
    if ctx.attr.language == "rust":
        # wit-bindgen generates a file based on the world/package name
        # For now, use a predictable name
        out_file = ctx.actions.declare_file(ctx.label.name + ".rs")
    elif ctx.attr.language == "c":
        # C generates multiple files
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_bindings")
        out_file = out_dir
    elif ctx.attr.language == "go":
        # Go generates multiple files (packages)
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_bindings")
        out_file = out_dir
    else:
        fail("Unsupported language: " + ctx.attr.language)

    # Get wit-bindgen tool from appropriate toolchain
    if ctx.attr.language == "go":
        # Check if TinyGo toolchain is available
        tinygo_toolchain = ctx.toolchains.get("@rules_wasm_component//toolchains:tinygo_toolchain_type")
        if not tinygo_toolchain:
            fail("TinyGo toolchain not available. Go WIT binding generation requires TinyGo toolchain.")
        wit_bindgen = tinygo_toolchain.wit_bindgen_go
    else:
        # Use standard wit-bindgen for other languages  
        toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
        wit_bindgen = toolchain.wit_bindgen

    # Get the main WIT library directory which contains the deps structure
    wit_library_dir = None
    if hasattr(ctx.attr.wit[DefaultInfo], "files"):
        for file in ctx.attr.wit[DefaultInfo].files.to_list():
            if file.is_directory:
                wit_library_dir = file
                break

    # Build command arguments based on tool
    if ctx.attr.language == "go":
        # wit-bindgen-go has different CLI: wit-bindgen-go generate --world <world> --out <dir> <wit-path>
        cmd_args = ["generate"]
        if wit_info.world_name:
            cmd_args.extend(["--world", wit_info.world_name])
    else:
        # Standard wit-bindgen CLI: wit-bindgen <language> --world <world> ...
        cmd_args = [ctx.attr.language]
        if wit_info.world_name:
            cmd_args.extend(["--world", wit_info.world_name])

    # Add interface mappings (--with)
    cmd_args.extend(_build_with_args(ctx.attr.with_mappings))

    # Add ownership model
    if ctx.attr.ownership != "owning":
        cmd_args.extend(["--ownership", ctx.attr.ownership])

    # Add additional derive attributes
    cmd_args.extend(_build_derive_args(ctx.attr.additional_derives))

    # Add async interface configuration
    cmd_args.extend(_build_async_args(ctx.attr.async_interfaces))

    # Add format flag if requested
    if ctx.attr.format_code:
        cmd_args.append("--format")

    # Add generate-all flag if requested
    if ctx.attr.generate_all:
        cmd_args.append("--generate-all")

    # Add additional options
    if ctx.attr.options:
        cmd_args.extend(ctx.attr.options)

    # For Rust, configure based on generation mode
    if ctx.attr.language == "rust":
        if ctx.attr.generation_mode == "native-guest":
            # Native-guest mode: Use std runtime for native execution (no WebAssembly)
            cmd_args.extend(["--runtime-path", "crate::wit_bindgen::rt"])
        else:
            # Default guest mode - generate component implementation bindings
            cmd_args.extend(["--runtime-path", "crate::wit_bindgen::rt"])

            # Make the export macro public so it can be used from separate crates
            cmd_args.append("--pub-export-macro")

    # Note: we'll run wit-bindgen from the deps directory to resolve packages

    # Add WIT files at the end (positional argument)
    # We'll adjust the paths when we have deps_dir
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
            if wit_info.wit_deps and len(wit_info.wit_deps.to_list()) > 0 and not ctx.attr.generate_all:
                # Add --generate-all to handle external dependencies automatically
                # (unless explicitly controlled by generate_all attribute)
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
                mnemonic = "WitBindgen",
                progress_message = "Generating {} bindings for {}".format(
                    ctx.attr.language,
                    ctx.label,
                ),
            )

            # Use a structured Python script to find and copy the generated file
            copy_script = ctx.actions.declare_file(ctx.label.name + "_copy_binding.py")
            script_content = '''#!/usr/bin/env python3
import os
import shutil
import sys
from pathlib import Path

def main():
    out_dir = sys.argv[1]
    out_file = sys.argv[2]

    # Find generated .rs files in the output directory
    out_path = Path(out_dir)
    rs_files = list(out_path.glob("*.rs"))

    if not rs_files:
        print(f"Error: No .rs file generated by wit-bindgen in {out_dir}")
        sys.exit(1)

    if len(rs_files) > 1:
        print(f"Warning: Multiple .rs files found, using first one: {rs_files[0].name}")
        for rs_file in rs_files:
            print(f"  Found: {rs_file.name}")

    # Copy the first (or only) .rs file to the expected location
    source_file = rs_files[0]
    try:
        shutil.copy2(str(source_file), out_file)
        print(f"Successfully copied: {source_file.name} -> {Path(out_file).name}")
    except Exception as e:
        print(f"Error copying generated binding: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
'''

            ctx.actions.write(
                output = copy_script,
                content = script_content,
                is_executable = True,
            )

            ctx.actions.run(
                executable = copy_script,
                arguments = [out_dir.path, out_file.path],
                inputs = [out_dir, copy_script],
                outputs = [out_file],
                mnemonic = "CopyGeneratedBinding",
                progress_message = "Copying generated binding for {}".format(ctx.label),
            )
        else:
            # No dependencies - run wit-bindgen directly on WIT files
            ctx.actions.run(
                executable = wit_bindgen,
                arguments = cmd_args + ["--out-dir", out_dir.path],
                inputs = wit_info.wit_files,
                outputs = [out_file, out_dir],
                mnemonic = "WitBindgen",
                progress_message = "Generating {} bindings for {}".format(
                    ctx.attr.language,
                    ctx.label,
                ),
            )
    elif ctx.attr.language == "go":
        # Handle Go wit-bindgen-go specifically
        if wit_library_dir:
            # Run wit-bindgen-go directly on the WIT library directory
            bindgen_args = cmd_args + ["--out", out_file.path, wit_library_dir.path]
            
            ctx.actions.run(
                executable = wit_bindgen,
                arguments = bindgen_args,
                inputs = depset(
                    direct = [wit_library_dir],
                    transitive = [wit_info.wit_files, wit_info.wit_deps] if wit_info.wit_deps else [wit_info.wit_files],
                ),
                outputs = [out_file],
                mnemonic = "GoWitBindgen",
                progress_message = "Generating Go WIT bindings for {}".format(ctx.label),
            )
        else:
            # No dependencies - run wit-bindgen-go directly on WIT files
            wit_file = wit_info.wit_files.to_list()[0] if wit_info.wit_files.to_list() else None
            if not wit_file:
                fail("No WIT files found")
                
            bindgen_args = cmd_args + ["--out", out_file.path, wit_file.path]
            
            ctx.actions.run(
                executable = wit_bindgen,
                arguments = bindgen_args,
                inputs = wit_info.wit_files,
                outputs = [out_file],
                mnemonic = "GoWitBindgen",
                progress_message = "Generating Go WIT bindings for {}".format(ctx.label),
            )
    else:
        # For other languages, create dependency structure using hermetic Go tool
        if wit_library_dir:
            # Create dependency structure for non-Rust languages using hermetic Go binary
            deps_dir = ctx.actions.declare_directory(ctx.label.name + "_wit_deps")
            config_file = ctx.actions.declare_file(ctx.label.name + "_wit_config.json")

            # Get the WIT file basename for the command
            main_wit_file = wit_file_args[0] if wit_file_args else ""
            wit_basename = main_wit_file.split("/")[-1] if main_wit_file else ""

            # Build JSON configuration for hermetic Go tool
            # Use manual JSON construction since Starlark doesn't have json.encode in all versions
            ops_config_json = """{{
  "workspace_dir": "{}",
  "operations": [
    {{
      "type": "copy_directory_contents",
      "src_path": "{}",
      "dest_path": "."
    }},
    {{
      "type": "run_command",
      "command": "{}",
      "args": {},
      "work_dir": ".",
      "output_file": "../{}"
    }}
  ]
}}""".format(
                deps_dir.path,
                wit_library_dir.path,
                wit_bindgen.path,
                str(cmd_args[:-len(wit_file_args)] + ([wit_basename] if wit_basename else [])).replace("'", '"'),
                out_file.basename,
            )

            # Write configuration file
            ctx.actions.write(
                output = config_file,
                content = ops_config_json,
            )

            # Get hermetic file operations tool from toolchain
            file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
            file_ops_tool = file_ops_toolchain.file_ops_component

            # Execute structured dependency setup and wit-bindgen using hermetic Go tool
            ctx.actions.run(
                executable = file_ops_tool,
                arguments = [config_file.path],
                inputs = depset(
                    direct = [wit_library_dir, config_file],
                    transitive = [wit_info.wit_files, wit_info.wit_deps],
                ),
                outputs = [out_file, deps_dir],
                tools = [wit_bindgen],
                mnemonic = "WitBindgenHermetic",
                progress_message = "Generating {} bindings with hermetic deps for {}".format(
                    ctx.attr.language,
                    ctx.label,
                ),
            )
        else:
            # No dependencies - use original approach
            ctx.actions.run(
                executable = wit_bindgen,
                arguments = cmd_args,
                inputs = depset(
                    direct = [wit_library_dir] if wit_library_dir else [],
                    transitive = [wit_info.wit_files, wit_info.wit_deps],
                ),
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
        "generation_mode": attr.string(
            values = ["guest", "native-guest"],
            default = "guest",
            doc = "Generation mode: 'guest' for WASM component implementation, 'native-guest' for native application bindings",
        ),
        "with_mappings": attr.string_dict(
            doc = "Interface and type remappings (key=value pairs). Maps WIT interfaces/types to existing Rust modules or 'generate'.",
            default = {},
        ),
        "ownership": attr.string(
            values = ["owning", "borrowing", "borrowing-duplicate-if-necessary"],
            default = "owning",
            doc = "Type ownership model for generated bindings",
        ),
        "additional_derives": attr.string_list(
            doc = "Additional derive attributes to add to generated types (e.g., ['Clone', 'Debug', 'Serialize'])",
            default = [],
        ),
        "async_interfaces": attr.string_list(
            doc = "Interfaces or functions to generate as async (e.g., ['my:pkg/interface#method', 'all'])",
            default = [],
        ),
        "format_code": attr.bool(
            doc = "Whether to run formatter on generated code",
            default = True,
        ),
        "generate_all": attr.bool(
            doc = "Whether to generate all interfaces not specified in with_mappings",
            default = False,
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
        "@rules_wasm_component//toolchains:tinygo_toolchain_type",
    ],
    doc = """
    Generates language bindings from WIT files.

    This rule uses wit-bindgen to generate language-specific bindings
    from WIT interface definitions.

    Example:
        wit_bindgen(
            name = "my_bindings",
            wit = ":my_interfaces",
            language = "rust",
            with_mappings = {
                "wasi:io/poll": "wasi::io::poll",
                "my:custom/interface": "generate",
                "my:resource/type": "crate::MyCustomType",
            },
            ownership = "borrowing",
            additional_derives = ["Clone", "Debug"],
        )

    """,
)
