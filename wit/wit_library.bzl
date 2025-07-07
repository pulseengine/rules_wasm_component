"""WIT library rule implementation"""

load("//providers:providers.bzl", "WitInfo")

def _wit_library_impl(ctx):
    """Implementation of wit_library rule"""
    
    # Collect all WIT files
    wit_files = depset(ctx.files.srcs)
    
    # Collect dependencies
    wit_deps = depset(
        transitive = [dep[WitInfo].wit_files for dep in ctx.attr.deps]
    )
    all_wit_deps = depset(
        transitive = [dep[WitInfo].wit_deps for dep in ctx.attr.deps]
    )
    
    # TODO: Parse WIT files to extract metadata
    # For now, use simple heuristics
    package_name = ctx.attr.package_name or ctx.label.name
    
    # Create output directory with proper deps structure
    out_dir = ctx.actions.declare_directory(ctx.label.name + "_wit")
    
    # Prepare inputs including all transitive dependencies and dependency outputs
    dep_outputs = []
    for dep in ctx.attr.deps:
        dep_outputs.extend(dep[DefaultInfo].files.to_list())
    
    all_inputs = depset(
        direct = ctx.files.srcs + dep_outputs,
        transitive = [wit_deps, all_wit_deps]
    )
    
    # Create WIT directory structure with dependencies
    dep_copy_commands = []
    for dep in ctx.attr.deps:
        dep_info = dep[WitInfo]
        # Convert package name with colons to directory path
        dep_dir = dep_info.package_name.replace(":", "/")
        dep_copy_commands.append(
            "mkdir -p {out_dir}/deps/{dep_dir}".format(
                out_dir = out_dir.path,
                dep_dir = dep_dir,
            )
        )
        # Get the dependency's output directory (should be a single directory)
        dep_output_dir = None
        for file in dep[DefaultInfo].files.to_list():
            if file.is_directory:
                dep_output_dir = file
                break
        
        if dep_output_dir:
            # Link all files from the dependency's output directory using absolute paths
            dep_copy_commands.append(
                "for f in {dep_out}/*; do ln -sf \"$(realpath \"$f\")\" {out_dir}/deps/{dep_dir}/; done".format(
                    dep_out = dep_output_dir.path,
                    out_dir = out_dir.path,
                    dep_dir = dep_dir,
                )
            )
        else:
            # Fallback to source files if no output directory found
            for wit_file in dep_info.wit_files.to_list():
                dep_copy_commands.append(
                    "ln -sf {src} {out_dir}/deps/{dep_dir}/".format(
                        src = wit_file.path,
                        out_dir = out_dir.path,
                        dep_dir = dep_dir,
                    )
                )
    
    # Create deps.toml if there are dependencies
    deps_toml_content = ""
    if ctx.attr.deps:
        deps_toml_content = "[deps]\n"
        for dep in ctx.attr.deps:
            dep_info = dep[WitInfo]
            # Convert package name with colons to directory path
            dep_dir = dep_info.package_name.replace(":", "/")
            deps_toml_content += '"{}"\npath = "./deps/{}"\n\n'.format(
                dep_info.package_name,
                dep_dir,
            )
    
    ctx.actions.run_shell(
        inputs = all_inputs,
        outputs = [out_dir],
        command = """
            mkdir -p {out_dir}
            
            # Copy source WIT files
            for src in {srcs}; do
                cp "$src" {out_dir}/
            done
            
            # Create dependency structure using symlinks to save space
            {dep_commands}
            
            # Create deps.toml if needed
            if [ -n "{deps_toml}" ]; then
                cat > {out_dir}/deps.toml << 'EOF'
{deps_toml}
EOF
            fi
        """.format(
            out_dir = out_dir.path,
            srcs = " ".join([f.path for f in ctx.files.srcs]),
            dep_commands = "\n".join(dep_copy_commands),
            deps_toml = deps_toml_content,
        ),
        mnemonic = "ProcessWit",
        progress_message = "Processing WIT files for %s" % ctx.label,
    )
    
    # Create provider
    wit_info = WitInfo(
        wit_files = wit_files,
        wit_deps = wit_deps,
        package_name = package_name,
        world_name = ctx.attr.world,
        interface_names = ctx.attr.interfaces,
    )
    
    return [
        wit_info,
        DefaultInfo(files = depset([out_dir])),
    ]

wit_library = rule(
    implementation = _wit_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".wit"],
            mandatory = True,
            doc = "WIT source files",
        ),
        "deps": attr.label_list(
            providers = [WitInfo],
            doc = "WIT dependencies",
        ),
        "package_name": attr.string(
            doc = "WIT package name (defaults to target name)",
        ),
        "world": attr.string(
            doc = "Optional world name to export",
        ),
        "interfaces": attr.string_list(
            doc = "List of interface names defined in this library",
        ),
    },
    doc = """
    Defines a WIT (WebAssembly Interface Types) library.
    
    This rule processes WIT files and makes them available for use
    in WASM component builds and binding generation.
    
    Example:
        wit_library(
            name = "my_interfaces",
            srcs = ["my-interface.wit"],
            package_name = "my:interfaces",
            interfaces = ["api", "types"],
        )
    """,
)