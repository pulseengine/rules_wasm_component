"""Bazel rules for JavaScript/TypeScript WebAssembly components using jco"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//providers:providers.bzl", "WasmComponentInfo")

def _js_component_impl(ctx):
    """Implementation of js_component rule"""

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
        package_json = ctx.actions.declare_file("generated_package.json")
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

    # Create working directory
    work_dir = ctx.actions.declare_directory(ctx.attr.name + "_work")

    # Prepare source files in working directory
    args = ctx.actions.args()
    args.add("--work-dir", work_dir.path)
    args.add("--output", component_wasm.path)
    args.add("--wit", wit_file.path)
    args.add("--package-json", package_json.path)
    args.add("--entry-point", ctx.attr.entry_point)
    
    # Add optimization flags
    if ctx.attr.optimize:
        args.add("--optimize")
    
    if ctx.attr.minify:
        args.add("--minify")
    
    # Add source files
    for src in source_files:
        args.add("--src", src.path)

    # Create preparation script
    prep_script = ctx.actions.declare_file(ctx.attr.name + "_prep.js")
    prep_script_content = """
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const config = {};
for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace('--', '');
    const value = args[i + 1];
    if (key === 'src') {
        if (!config.srcs) config.srcs = [];
        config.srcs.push(value);
    } else {
        config[key] = value;
    }
}

// Create working directory structure  
fs.mkdirSync(config.workDir, { recursive: true });

// Copy package.json
fs.copyFileSync(config.packageJson, path.join(config.workDir, 'package.json'));

// Copy source files maintaining directory structure
config.srcs.forEach(srcPath => {
    const relativePath = path.relative(process.cwd(), srcPath);
    const destPath = path.join(config.workDir, path.basename(relativePath));
    fs.copyFileSync(srcPath, destPath);
});

// Copy WIT file
fs.copyFileSync(config.wit, path.join(config.workDir, 'component.wit'));

console.log('Prepared JavaScript component sources in', config.workDir);
"""

    ctx.actions.write(
        output = prep_script,
        content = prep_script_content,
    )

    # Run preparation script
    ctx.actions.run(
        executable = node,
        arguments = [prep_script.path] + [args],
        inputs = [prep_script, package_json, wit_file] + source_files,
        outputs = [work_dir],
        mnemonic = "PrepareJSComponent",
        progress_message = "Preparing JavaScript component sources for %s" % ctx.label,
    )

    # Run jco to build component
    jco_args = ctx.actions.args()
    jco_args.add("new")
    jco_args.add(work_dir.path)
    jco_args.add("--wit", paths.join(work_dir.path, "component.wit"))
    jco_args.add("--out", component_wasm.path)
    
    if ctx.attr.world:
        jco_args.add("--world", ctx.attr.world)
    
    # Add jco-specific flags
    if ctx.attr.disable_feature_detection:
        jco_args.add("--disable-feature-detection")
    
    if ctx.attr.compat:
        jco_args.add("--compat")

    ctx.actions.run(
        executable = jco,
        arguments = [jco_args],
        inputs = [work_dir],
        outputs = [component_wasm],
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
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm])),
    ]

js_component = rule(
    implementation = _js_component_impl,
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
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
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
    """Implementation of jco_transpile rule"""

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
    """Implementation of npm_install rule for JavaScript components"""

    # Get jco toolchain
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    npm = jco_toolchain.npm

    # Package.json file
    package_json = ctx.file.package_json

    # Output node_modules directory
    node_modules = ctx.actions.declare_directory("node_modules")

    # Create a working directory to isolate npm install
    work_dir = ctx.actions.declare_directory(ctx.attr.name + "_npm_work")

    # Copy package.json to working directory and run npm install
    setup_script = ctx.actions.declare_file(ctx.attr.name + "_npm_setup.sh")
    setup_content = """#!/bin/bash
set -e

WORK_DIR="{work_dir}"
PACKAGE_JSON="{package_json}"
NODE_MODULES="{node_modules}"

# Create working directory
mkdir -p "$WORK_DIR"

# Copy package.json
cp "$PACKAGE_JSON" "$WORK_DIR/package.json"

# Run npm install in working directory
cd "$WORK_DIR"
{npm} install

# Copy node_modules to output
cp -r node_modules/* "$NODE_MODULES/"

echo "NPM install completed successfully"
""".format(
        work_dir = work_dir.path,
        package_json = package_json.path,
        node_modules = node_modules.path,
        npm = npm.path,
    )

    ctx.actions.write(
        output = setup_script,
        content = setup_content,
        is_executable = True,
    )

    ctx.actions.run(
        executable = setup_script,
        inputs = [package_json],
        outputs = [work_dir, node_modules],
        mnemonic = "NPMInstall",
        progress_message = "Installing NPM dependencies for %s" % ctx.label,
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
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
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