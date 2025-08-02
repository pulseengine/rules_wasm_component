"""Bazel rules for WebAssembly Package Tools (wkg)"""

def _wkg_fetch_impl(ctx):
    """Implementation of wkg_fetch rule"""

    wkg_toolchain = ctx.toolchains["//toolchains:wkg_toolchain_type"]
    wkg = wkg_toolchain.wkg

    # Output files
    component_file = ctx.actions.declare_file(ctx.attr.name + ".wasm")
    wit_dir = ctx.actions.declare_directory(ctx.attr.name + "_wit")
    # Note: wkg get doesn't create a lock file

    # Create config file if registry is specified
    config_content = ""
    if ctx.attr.registry:
        config_content = """
[registry]
default = "{registry}"

[registries."{registry}"]
url = "{registry}"
""".format(registry = ctx.attr.registry)

    config_file = None
    if config_content:
        config_file = ctx.actions.declare_file("wkg_config.toml")
        ctx.actions.write(
            output = config_file,
            content = config_content,
        )

    # Build command arguments
    args = ctx.actions.args()
    args.add("get")

    # Format package spec as package@version
    package_spec = ctx.attr.package
    if ctx.attr.version:
        package_spec += "@" + ctx.attr.version
    args.add(package_spec)

    if config_file:
        args.add("--config", config_file.path)

    # Output directory for fetched components
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_fetched")
    args.add("--output", output_dir.path + "/")

    # Use a sandbox-friendly cache directory
    cache_dir = ctx.actions.declare_directory(ctx.attr.name + "_cache")
    args.add("--cache", cache_dir.path)

    # Allow overwriting existing files
    args.add("--overwrite")

    # Run wkg fetch
    inputs = []
    if config_file:
        inputs.append(config_file)

    ctx.actions.run(
        executable = wkg,
        arguments = [args],
        inputs = inputs,
        outputs = [output_dir, cache_dir],
        mnemonic = "WkgFetch",
        progress_message = "Fetching WebAssembly component {}".format(ctx.attr.package),
    )

    # Extract component and WIT files from fetched directory
    ctx.actions.run_shell(
        command = '''
            # Find the component file
            COMPONENT=$(find {fetched_dir} -name "*.wasm" | head -1)
            if [ -n "$COMPONENT" ]; then
                cp "$COMPONENT" {component_output}
            else
                echo "No component file found in fetched package" >&2
                exit 1
            fi

            # Copy WIT files
            if [ -d {fetched_dir}/wit ]; then
                cp -r {fetched_dir}/wit/* {wit_output}/
            fi
        '''.format(
            fetched_dir = output_dir.path,
            component_output = component_file.path,
            wit_output = wit_dir.path,
        ),
        inputs = [output_dir],
        outputs = [component_file, wit_dir],
        mnemonic = "WkgExtract",
        progress_message = "Extracting component from fetched package",
    )

    return [
        DefaultInfo(files = depset([component_file, wit_dir])),
        OutputGroupInfo(
            component = depset([component_file]),
            wit = depset([wit_dir]),
            # No lock file created by wkg get
        ),
    ]

wkg_fetch = rule(
    implementation = _wkg_fetch_impl,
    attrs = {
        "package": attr.string(
            doc = "Package name to fetch (e.g., 'wasi:http')",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "Package version to fetch (defaults to latest)",
        ),
        "registry": attr.string(
            doc = "Registry URL to fetch from (optional)",
        ),
    },
    toolchains = ["//toolchains:wkg_toolchain_type"],
    doc = "Fetch a WebAssembly component package from a registry",
)

def _wkg_lock_impl(ctx):
    """Implementation of wkg_lock rule to generate lock files"""

    wkg_toolchain = ctx.toolchains["//toolchains:wkg_toolchain_type"]
    wkg = wkg_toolchain.wkg

    # Output lock file
    lock_file = ctx.actions.declare_file("wkg.lock")

    # Create wkg.toml file with dependencies
    deps_content = "[dependencies]\n"
    for dep in ctx.attr.dependencies:
        parts = dep.split(":")
        if len(parts) >= 2:
            name = ":".join(parts[:-1])
            version = parts[-1]
            deps_content += '{} = "{}"\n'.format(name, version)
        else:
            deps_content += '{} = "*"\n'.format(dep)

    wkg_toml = ctx.actions.declare_file(ctx.attr.name + "_wkg.toml")
    ctx.actions.write(
        output = wkg_toml,
        content = deps_content,
    )

    # Registry config
    config_content = ""
    if ctx.attr.registry:
        config_content = """
[registry]
default = "{registry}"

[registries."{registry}"]
url = "{registry}"
""".format(registry = ctx.attr.registry)

    config_file = None
    if config_content:
        config_file = ctx.actions.declare_file("wkg_config.toml")
        ctx.actions.write(
            output = config_file,
            content = config_content,
        )

    # Build command arguments
    args = ctx.actions.args()
    args.add("lock")
    args.add("--manifest", wkg_toml.path)
    args.add("--output", lock_file.path)

    if config_file:
        args.add("--config", config_file.path)

    # Run wkg lock
    inputs = [wkg_toml]
    if config_file:
        inputs.append(config_file)

    ctx.actions.run(
        executable = wkg,
        arguments = [args],
        inputs = inputs,
        outputs = [lock_file],
        mnemonic = "WkgLock",
        progress_message = "Generating wkg.lock file",
    )

    return [DefaultInfo(files = depset([lock_file]))]

wkg_lock = rule(
    implementation = _wkg_lock_impl,
    attrs = {
        "dependencies": attr.string_list(
            doc = "List of dependencies in 'name:version' format",
            default = [],
        ),
        "registry": attr.string(
            doc = "Registry URL to resolve dependencies from (optional)",
        ),
    },
    toolchains = ["//toolchains:wkg_toolchain_type"],
    doc = "Generate a wkg.lock file for reproducible dependency resolution",
)

def _wkg_publish_impl(ctx):
    """Implementation of wkg_publish rule"""

    wkg_toolchain = ctx.toolchains["//toolchains:wkg_toolchain_type"]
    wkg = wkg_toolchain.wkg

    # Component file to publish
    component = ctx.file.component

    # Create wkg.toml metadata file
    metadata_content = """
[package]
name = "{name}"
version = "{version}"
""".format(
        name = ctx.attr.package_name,
        version = ctx.attr.version,
    )

    if ctx.attr.description:
        metadata_content += 'description = "{}"\n'.format(ctx.attr.description)

    if ctx.attr.authors:
        authors_str = ", ".join(['"{}"'.format(a) for a in ctx.attr.authors])
        metadata_content += "authors = [{}]\n".format(authors_str)

    if ctx.attr.license:
        metadata_content += 'license = "{}"\n'.format(ctx.attr.license)

    wkg_toml = ctx.actions.declare_file(ctx.attr.name + "_wkg.toml")
    ctx.actions.write(
        output = wkg_toml,
        content = metadata_content,
    )

    # Registry config
    config_content = ""
    if ctx.attr.registry:
        config_content = """
[registry]
default = "{registry}"

[registries."{registry}"]
url = "{registry}"
""".format(registry = ctx.attr.registry)

    config_file = None
    if config_content:
        config_file = ctx.actions.declare_file("wkg_config.toml")
        ctx.actions.write(
            output = config_file,
            content = config_content,
        )

    # Create publish script (since we can't directly publish in Bazel)
    publish_script = ctx.actions.declare_file(ctx.attr.name + "_publish.sh")
    script_content = '''#!/bin/bash
set -e

echo "Publishing WebAssembly component {package_name}:{version}"
echo "Component file: {component_path}"
echo "Metadata file: {metadata_path}"

# Note: This is a stub implementation
# In a real scenario, you would run:
# {wkg_path} publish --component {component_path} --manifest {metadata_path}
'''.format(
        package_name = ctx.attr.package_name,
        version = ctx.attr.version,
        component_path = component.path,
        metadata_path = wkg_toml.path,
        wkg_path = wkg.path,
    )

    if config_file:
        script_content += "# --config {}\n".format(config_file.path)

    script_content += 'echo "Publish script ready. Run this script to publish the component."\n'

    ctx.actions.write(
        output = publish_script,
        content = script_content,
        is_executable = True,
    )

    return [DefaultInfo(
        files = depset([publish_script, wkg_toml]),
        executable = publish_script,
    )]

wkg_publish = rule(
    implementation = _wkg_publish_impl,
    attrs = {
        "component": attr.label(
            doc = "WebAssembly component file to publish",
            allow_single_file = [".wasm"],
            mandatory = True,
        ),
        "package_name": attr.string(
            doc = "Package name for publishing",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "Package version for publishing",
            mandatory = True,
        ),
        "description": attr.string(
            doc = "Package description (optional)",
        ),
        "authors": attr.string_list(
            doc = "List of package authors (optional)",
            default = [],
        ),
        "license": attr.string(
            doc = "Package license (optional)",
        ),
        "registry": attr.string(
            doc = "Registry URL to publish to (optional)",
        ),
    },
    toolchains = ["//toolchains:wkg_toolchain_type"],
    executable = True,
    doc = "Publish a WebAssembly component to a registry",
)
