"""WIT library rule implementation"""

load("//providers:providers.bzl", "WitInfo")

def _wit_library_impl(ctx):
    """Implementation of wit_library rule"""

    # Collect all WIT files
    wit_files = depset(ctx.files.srcs)

    # Collect dependencies
    wit_deps = depset(
        transitive = [dep[WitInfo].wit_files for dep in ctx.attr.deps],
    )
    all_wit_deps = depset(
        transitive = [dep[WitInfo].wit_deps for dep in ctx.attr.deps],
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
        transitive = [wit_deps, all_wit_deps],
    )

    # Collect all transitive WIT dependencies properly using depsets
    all_wit_files = depset(
        direct = ctx.files.srcs,
        transitive = [dep[WitInfo].wit_files for dep in ctx.attr.deps] + [dep[WitInfo].wit_deps for dep in ctx.attr.deps],
    )

    # Build dependency mapping for deps/ structure
    dep_info_list = []
    for dep in ctx.attr.deps:
        dep_info = dep[WitInfo]
        # Convert package name to directory name: external:lib@1.0.0 -> external-lib
        simple_name = dep_info.package_name.split("@")[0].replace(":", "-")
        dep_info_list.append({
            "package_name": dep_info.package_name,
            "simple_name": simple_name,
            "wit_files": [f.path for f in dep_info.wit_files.to_list()],
        })

    # Create deps.toml content for wit-deps tool compatibility (not required by wit-bindgen)
    deps_toml_content = ""
    if dep_info_list:
        deps_toml_content = "[deps]\n"
        for dep_info in dep_info_list:
            deps_toml_content += '"{}"\npath = "./deps/{}"\n\n'.format(
                dep_info["package_name"],
                dep_info["simple_name"],
            )

    # Create configuration for wit_structure tool
    config = {
        "output_dir": out_dir.path,
        "source_files": [f.path for f in ctx.files.srcs],
        "dependencies": dep_info_list,
        "deps_toml_content": deps_toml_content,
    }

    config_file = ctx.actions.declare_file(ctx.label.name + "_config.json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(config),
    )

    # Check for missing dependencies and provide helpful suggestions
    if ctx.files.srcs:
        analyzer_config = {
            "analysis_mode": "check",
            "workspace_dir": ".",  # Will be the workspace root
            "wit_file": ctx.files.srcs[0].path,  # Analyze the first WIT file
            "missing_packages": [],
        }
        
        analyzer_config_file = ctx.actions.declare_file(ctx.label.name + "_analyzer_config.json")
        ctx.actions.write(
            output = analyzer_config_file,
            content = json.encode(analyzer_config),
        )
        
        analyzer_output = ctx.actions.declare_file(ctx.label.name + "_analysis.json")
        
        # Run dependency analysis (this will help debug missing deps)
        ctx.actions.run(
            executable = ctx.executable._wit_dependency_analyzer,
            arguments = [analyzer_config_file.path],
            inputs = depset(direct = [analyzer_config_file] + ctx.files.srcs),
            outputs = [analyzer_output],
            mnemonic = "AnalyzeWitDependencies",
            progress_message = "Analyzing WIT dependencies for %s" % ctx.label,
            # Note: This analysis runs but doesn't fail the build - it generates suggestions
        )

    # Use custom tool instead of shell commands - this is the Bazel-native way
    ctx.actions.run(
        executable = ctx.executable._wit_structure_tool,
        arguments = [config_file.path],
        inputs = depset(
            direct = [config_file] + ctx.files.srcs,
            transitive = [dep[WitInfo].wit_files for dep in ctx.attr.deps],
        ),
        outputs = [out_dir],
        mnemonic = "CreateWitStructure",
        progress_message = "Creating WIT directory structure for %s" % ctx.label,
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
        "_wit_structure_tool": attr.label(
            default = "//tools/wit_structure",
            executable = True,
            cfg = "exec",
        ),
        "_wit_dependency_analyzer": attr.label(
            default = "//tools/wit_dependency_analyzer",
            executable = True,
            cfg = "exec",
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
