# Copyright 2024 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""JavaScript/TypeScript WebAssembly Component Model rules

Modern JavaScript/TypeScript support for WebAssembly Component Model using:
- Node.js 18.20.8+ with hermetic toolchain management
- jco v1.4.0+ for component compilation and optimization
- Bazel-native implementation with zero shell scripts
- Cross-platform compatibility (Windows/macOS/Linux)
- TypeScript support with automatic transpilation
- NPM dependency management integration
- Component composition and binding generation

Example usage:

    js_component(
        name = "web_service",
        srcs = ["index.js", "service.js"],
        package_json = "package.json",
        wit = "//wit:web-interface",
        world = "web-service",
        entry_point = "index.js",
        npm_dependencies = {
            "express": "^4.18.0",
            "@types/node": "^18.0.0",
        },
    )
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//providers:providers.bzl", "WasmComponentInfo")
load("//rust:transitions.bzl", "wasm_transition")

def _js_component_impl(ctx):
    """Implementation of js_component rule for JavaScript/TypeScript components.

    Compiles JavaScript or TypeScript source code into WebAssembly components
    using jco (JavaScript Component Compiler). Handles package.json generation,
    module resolution, and component creation.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: JavaScript/TypeScript source files
            - ctx.file.wit: WIT interface definition file
            - ctx.attr.entry_point: Main entry point file (default: "index.js")
            - ctx.file.package_json: Optional package.json file
            - ctx.attr.npm_dependencies: NPM dependencies to include
            - ctx.attr.world: WIT world to target
            - ctx.attr.optimize: Enable optimizations
            - ctx.attr.minify: Minify generated code

    Returns:
        List of providers:
        - WasmComponentInfo: Component metadata for JavaScript
        - DefaultInfo: Component .wasm file

    The implementation:
    1. Sets up jco toolchain (jco, node, npm)
    2. Creates or uses provided package.json
    3. Creates temporary workspace with all source files
    4. Runs jco componentize from workspace directory for proper module resolution
    5. Creates WasmComponentInfo provider with JavaScript-specific metadata

    Module Resolution:
        jco requires running from the directory containing source files
        to properly resolve ES6 module imports.
    """

    # Get jco toolchain
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    jco = jco_toolchain.jco
    node = jco_toolchain.node
    npm = jco_toolchain.npm

    # Output component file
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input source files
    source_files = ctx.files.srcs
    wit_file = ctx.file.wit

    # Package.json file (required for Node.js projects)
    package_json = ctx.file.package_json
    if not package_json:
        # Generate a basic package.json if not provided
        package_json = ctx.actions.declare_file(ctx.attr.name + "_generated_package.json")
        package_content = {
            "name": ctx.attr.name,
            "version": "1.0.0",
            "type": "module",
            "dependencies": ctx.attr.npm_dependencies,
        }
        ctx.actions.write(
            output = package_json,
            content = json.encode(package_content),
        )

    # Find the entry point file
    entry_point_file = None
    for src in source_files:
        if src.basename == ctx.attr.entry_point:
            entry_point_file = src
            break

    if not entry_point_file:
        fail("Entry point '{}' not found in sources: {}".format(
            ctx.attr.entry_point,
            [src.basename for src in source_files],
        ))

    # Create a build script that sets up a workspace and runs jco with proper working directory
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build.sh")

    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "# Create temporary workspace",
        "WORK_DIR=$(mktemp -d)",
        "echo \"Working in: $WORK_DIR\"",
        "",
        "# Copy all source files to workspace (flattened)",
    ]

    for src in source_files:
        script_lines.append("cp \"{}\" \"$WORK_DIR/{}\"".format(src.path, src.basename))

    if package_json:
        script_lines.append("cp \"{}\" \"$WORK_DIR/package.json\"".format(package_json.path))

    # Build jco command - change to workspace and use relative paths for module resolution
    script_lines.extend([
        "",
        "# Save original directory for absolute paths",
        "ORIGINAL_DIR=\"$(pwd)\"",
        "",
        "# Change to workspace directory so jco resolves modules correctly",
        "cd \"$WORK_DIR\"",
        "",
        "# Debug: show current directory and files",
        "echo \"Current directory: $(pwd)\"",
        "echo \"Original directory: $ORIGINAL_DIR\"",
        "echo \"Files in workspace:\"",
        "ls -la",
        "echo \"JCO binary path: $ORIGINAL_DIR/{}\"".format(jco.path),
        "echo \"About to run jco...\"",
        "",
        "# Run jco componentize from workspace with correct module resolution",
    ])

    # Build jco command - use relative path for entry point for proper ES6 module resolution
    jco_cmd_parts = [
        "\"$ORIGINAL_DIR/{}\"".format(jco.path),  # jco binary path
        "componentize",
        "\"{}\"".format(ctx.attr.entry_point),  # Relative path to entry point in workspace
        "--wit \"$ORIGINAL_DIR/{}\"".format(wit_file.path),  # Absolute path to WIT file
        "--out \"$ORIGINAL_DIR/{}\"".format(component_wasm.path),  # Absolute path to output
    ]

    if ctx.attr.world:
        jco_cmd_parts.append("--world-name {}".format(ctx.attr.world))

    if ctx.attr.disable_feature_detection:
        jco_cmd_parts.append("--disable-feature-detection")

    if ctx.attr.compat:
        jco_cmd_parts.append("--compat")

    script_lines.extend([
        " ".join(jco_cmd_parts),
        "",
        "echo \"Component build complete\"",
    ])

    ctx.actions.write(
        output = build_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # All input files
    all_inputs = list(source_files) + [wit_file]
    if package_json:
        all_inputs.append(package_json)

    ctx.actions.run(
        executable = build_script,
        inputs = all_inputs,
        outputs = [component_wasm],
        tools = [jco],
        mnemonic = "JCOBuild",
        progress_message = "Building JavaScript component %s with jco" % ctx.label,
    )

    # Create component info
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = wit_file,
            package_name = ctx.attr.package_name or "{}:component@1.0.0".format(ctx.attr.name),
        ),
        component_type = "component",
        imports = [],  # TODO: Parse from WIT
        exports = [ctx.attr.world] if ctx.attr.world else [],
        metadata = {
            "name": ctx.label.name,
            "language": "javascript",
            "target": "wasm32-wasi",
            "componentize_js": True,
        },
        profile = "release",  # ComponentizeJS always produces optimized output
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm])),
    ]

js_component = rule(
    implementation = _js_component_impl,
    cfg = wasm_transition,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".js", ".ts", ".mjs"],
            mandatory = True,
            doc = "JavaScript/TypeScript source files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies (other JavaScript libraries or components)",
        ),
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "package_json": attr.label(
            allow_single_file = ["package.json"],
            doc = "package.json file (auto-generated if not provided)",
        ),
        "entry_point": attr.string(
            default = "index.js",
            doc = "Main entry point file",
        ),
        "world": attr.string(
            doc = "WIT world to target (optional)",
        ),
        "package_name": attr.string(
            doc = "WIT package name (auto-generated if not provided)",
        ),
        "npm_dependencies": attr.string_dict(
            doc = "NPM dependencies to include in generated package.json",
        ),
        "optimize": attr.bool(
            default = True,
            doc = "Enable optimizations",
        ),
        "minify": attr.bool(
            default = False,
            doc = "Minify generated code",
        ),
        "disable_feature_detection": attr.bool(
            default = False,
            doc = "Disable WebAssembly feature detection",
        ),
        "compat": attr.bool(
            default = False,
            doc = "Enable compatibility mode for older JavaScript engines",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:jco_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Builds a WebAssembly component from JavaScript/TypeScript sources using jco.

    This rule compiles JavaScript or TypeScript code into a WebAssembly component
    that implements the specified WIT interface.

    Example:
        js_component(
            name = "my_js_component",
            srcs = [
                "src/index.js",
                "src/utils.js",
            ],
            wit = "component.wit",
            entry_point = "index.js",
            npm_dependencies = {
                "lodash": "^4.17.21",
            },
            optimize = True,
        )
    """,
)

def _jco_transpile_impl(ctx):
    """Implementation of jco_transpile rule for component-to-JavaScript conversion.

    Transpiles a compiled WebAssembly component back to JavaScript bindings
    for use in Node.js or browser environments. This is the reverse of
    js_component - it takes a .wasm component and generates .js/.ts files.

    Args:
        ctx: The rule context containing:
            - ctx.file.component: WebAssembly component file to transpile
            - ctx.attr.name_override: Override component name in generated code
            - ctx.attr.no_typescript: Disable TypeScript definition generation
            - ctx.attr.instantiation: Component instantiation mode (async/sync)
            - ctx.attr.map: Interface mappings for module resolution
            - ctx.attr.world_name: Name for generated world interface

    Returns:
        List of providers:
        - DefaultInfo: Generated transpiled JavaScript directory
        - OutputGroupInfo: Organized output (transpiled group)

    Generated output structure:
        <name>_transpiled/
            index.js              # Main entry point
            types.d.ts           # TypeScript definitions (if enabled)
            interfaces/          # Generated interface bindings
            ...

    Use cases:
        - Creating JavaScript bindings for WASM components
        - Integrating components into existing JS projects
        - Generating TypeScript definitions for type safety
    """

    # Get jco toolchain
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    jco = jco_toolchain.jco

    # Input component
    component = ctx.file.component

    # Output directory
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_transpiled")

    # Build jco transpile command
    args = ctx.actions.args()
    args.add("transpile")
    args.add(component.path)
    args.add("--out", output_dir.path)

    if ctx.attr.name_override:
        args.add("--name", ctx.attr.name_override)

    if ctx.attr.no_typescript:
        args.add("--no-typescript")

    if ctx.attr.instantiation:
        args.add("--instantiation", ctx.attr.instantiation)

    # Add map options
    for mapping in ctx.attr.map:
        args.add("--map", mapping)

    if ctx.attr.world_name:
        args.add("--world-name", ctx.attr.world_name)

    ctx.actions.run(
        executable = jco,
        arguments = [args],
        inputs = [component],
        outputs = [output_dir],
        mnemonic = "JCOTranspile",
        progress_message = "Transpiling component %s to JavaScript with jco" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([output_dir])),
        OutputGroupInfo(
            transpiled = depset([output_dir]),
        ),
    ]

jco_transpile = rule(
    implementation = _jco_transpile_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "WebAssembly component file to transpile",
        ),
        "name_override": attr.string(
            doc = "Override the component name in generated JavaScript",
        ),
        "no_typescript": attr.bool(
            default = False,
            doc = "Disable TypeScript definition generation",
        ),
        "instantiation": attr.string(
            values = ["async", "sync"],
            doc = "Component instantiation mode",
        ),
        "map": attr.string_list(
            doc = "Interface mappings in the form 'from=to'",
        ),
        "world_name": attr.string(
            doc = "Name for the generated world interface",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
    doc = """
    Transpiles a WebAssembly component to JavaScript using jco.

    This rule takes a compiled WebAssembly component and generates JavaScript
    bindings that can be used in Node.js or browser environments.

    Example:
        jco_transpile(
            name = "my_component_js",
            component = ":my_component.wasm",
            instantiation = "async",
            map = [
                "wasi:http/types@0.2.0=@wasi/http#types",
            ],
        )
    """,
)

def _npm_install_impl(ctx):
    """Implementation of npm_install rule for JavaScript component dependencies.

    Installs NPM dependencies from a package.json file into a node_modules
    directory for use in JavaScript component builds.

    Args:
        ctx: The rule context containing:
            - ctx.file.package_json: package.json file with dependencies

    Returns:
        List of providers:
        - DefaultInfo: node_modules directory with installed packages
        - OutputGroupInfo: Organized output (node_modules group)

    The implementation:
    1. Creates temporary workspace
    2. Copies package.json to workspace
    3. Runs npm install from workspace
    4. Copies resulting node_modules to output directory

    Execution requirements:
        - local: NPM install requires network access to fetch packages
        - This is NOT hermetic but necessary for NPM ecosystem

    Use cases:
        - Installing dependencies for js_component builds
        - Caching NPM packages in Bazel's output directory
        - Managing JavaScript dependencies declaratively
    """

    # Get jco toolchain
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    npm = jco_toolchain.npm

    # Package.json file
    package_json = ctx.file.package_json

    # Output node_modules directory
    node_modules = ctx.actions.declare_directory("node_modules")

    # Create a simple workspace for npm install
    build_script = ctx.actions.declare_file(ctx.attr.name + "_npm_install.sh")

    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "# Create temporary workspace",
        "WORK_DIR=$(mktemp -d)",
        "echo \"NPM install workspace: $WORK_DIR\"",
        "",
        "# Copy package.json to workspace",
        "cp \"{}\" \"$WORK_DIR/package.json\"".format(package_json.path),
        "",
        "# Save original directory and change to workspace",
        "ORIGINAL_DIR=\"$(pwd)\"",
        "cd \"$WORK_DIR\"",
        "\"$ORIGINAL_DIR/{}\" install".format(npm.path),
        "",
        "# Copy node_modules to output directory",
        "mkdir -p \"$(dirname \\\"$ORIGINAL_DIR/{}\\\")\"".format(node_modules.path),
        "cp -r node_modules \"$ORIGINAL_DIR/{}\"".format(node_modules.path),
        "",
        "echo \"NPM install complete\"",
    ]

    ctx.actions.write(
        output = build_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    ctx.actions.run(
        executable = build_script,
        inputs = [package_json],
        outputs = [node_modules],
        tools = [npm],
        mnemonic = "NPMInstall",
        progress_message = "Installing NPM dependencies for %s" % ctx.label,
        execution_requirements = {
            "local": "1",  # NPM install requires network access
        },
    )

    return [
        DefaultInfo(files = depset([node_modules])),
        OutputGroupInfo(
            node_modules = depset([node_modules]),
        ),
    ]

npm_install = rule(
    implementation = _npm_install_impl,
    attrs = {
        "package_json": attr.label(
            allow_single_file = ["package.json"],
            mandatory = True,
            doc = "package.json file with dependencies",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:jco_toolchain_type",
    ],
    doc = """
    Installs NPM dependencies for JavaScript components.

    This rule runs npm install to fetch dependencies specified in package.json,
    making them available for JavaScript component builds.

    Example:
        npm_install(
            name = "npm_deps",
            package_json = "package.json",
        )
    """,
)
