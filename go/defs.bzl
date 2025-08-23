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

"""TinyGo WASI Preview 2 WebAssembly component rules

State-of-the-art Go support for WebAssembly Component Model using:
- TinyGo v0.38.0+ with native WASI Preview 2 support
- Bazel-native implementation (zero shell scripts) ✅ ACHIEVED
- Cross-platform compatibility (Windows/macOS/Linux)
- Proper toolchain integration with hermetic builds
- Direct executable invocation with environment variables
- Universal File Operations Component for workspace preparation

Example usage:

    go_wasm_component(
        name = "my_component",
        srcs = ["main.go"],
        go_mod = "go.mod",
        wit = "//wit:interfaces",
        world = "my-world",
    )
"""

load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")
load("//rust:transitions.bzl", "wasm_transition")
load("//tools/bazel_helpers:file_ops_actions.bzl", "setup_go_module_action")

def _assert_valid_go_component_attrs(ctx):
    """Validates go_wasm_component attributes for common mistakes and deprecated patterns"""
    
    # Validate sources
    if not ctx.files.srcs:
        fail("go_wasm_component rule '{}' requires at least one Go source file in 'srcs'".format(ctx.label))
    
    # Ensure all source files are .go files
    for src in ctx.files.srcs:
        if not src.basename.endswith(".go"):
            fail("go_wasm_component rule '{}' source file '{}' must be a .go file".format(ctx.label, src.basename))
    
    # Validate optimization levels
    valid_optimizations = ["debug", "release", "size"]
    if ctx.attr.optimization not in valid_optimizations:
        fail("go_wasm_component rule '{}' has invalid optimization '{}'. Must be one of: {}".format(
            ctx.label, ctx.attr.optimization, ", ".join(valid_optimizations)))
    
    # Validate world name format if provided
    if ctx.attr.world:
        # WIT world names support namespaces with colons, hyphens, underscores, and forward slashes
        # Valid examples: "wasi:cli/command", "example:calculator/operations", "simple-world"
        allowed_chars = ctx.attr.world.replace("-", "").replace("_", "").replace(":", "").replace("/", "")
        if not allowed_chars.isalnum():
            fail("go_wasm_component rule '{}' has invalid world name '{}'. World names must be alphanumeric with hyphens, underscores, colons, and forward slashes".format(
                ctx.label, ctx.attr.world))

def _assert_valid_toolchain_setup(ctx, tinygo, wasm_tools):
    """Validates that required toolchains are properly configured"""
    
    if not tinygo:
        fail("TinyGo binary not found in toolchain for target '{}'".format(ctx.label))
    if not wasm_tools:
        fail("wasm-tools binary not found in toolchain for target '{}'".format(ctx.label))
    
    # Validate TinyGo version compatibility (basic check)
    if "tinygo" not in tinygo.basename.lower():
        fail("TinyGo toolchain binary '{}' for target '{}' does not appear to be TinyGo".format(
            tinygo.basename, ctx.label))

def _build_tool_path_env(ctx, tool_paths):
    """Build PATH environment variable from tool directories - THE BAZEL WAY"""
    # Detect platform - Bazel provides this via ctx
    is_windows = ctx.configuration.host_path_separator == ";"
    
    if is_windows:
        # Windows path separator
        if not tool_paths:
            return "C:\\Windows\\System32;C:\\Windows"
        return ";".join(tool_paths) + ";C:\\Windows\\System32;C:\\Windows"
    else:
        # Unix path separator
        if not tool_paths:
            return "/usr/bin:/bin"
        return ":".join(tool_paths) + ":/usr/bin:/bin"

def _go_wasm_component_impl(ctx):
    """Implementation of go_wasm_component rule - THE BAZEL WAY"""

    # Comprehensive validation following rules_rust patterns
    _assert_valid_go_component_attrs(ctx)

    # Get toolchains (Starlark doesn't support try-catch)
    tinygo_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:tinygo_toolchain_type"]
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]

    tinygo = tinygo_toolchain.tinygo
    wasm_tools = wasm_tools_toolchain.wasm_tools

    # Get hermetic Go binary from TinyGo toolchain
    go_binary = getattr(tinygo_toolchain, "go", None)
    if go_binary:
        print("DEBUG: Found hermetic Go binary from TinyGo toolchain: %s" % go_binary.path)
    else:
        print("DEBUG: No Go binary provided by TinyGo toolchain")

    # Get wasm-opt binary from TinyGo toolchain
    wasm_opt_binary = getattr(tinygo_toolchain, "wasm_opt", None)
    if wasm_opt_binary:
        print("DEBUG: Found wasm-opt binary from TinyGo toolchain: %s" % wasm_opt_binary.path)
    else:
        print("DEBUG: No wasm-opt binary provided by TinyGo toolchain")

    # Validate toolchain setup
    _assert_valid_toolchain_setup(ctx, tinygo, wasm_tools)

    # Prepare outputs
    wasm_module = ctx.actions.declare_file(ctx.attr.name + "_module.wasm")
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Step 1: Build Go module structure using Bazel file management
    go_module_files = _prepare_go_module(ctx, tinygo_toolchain)

    # Step 2: Compile with TinyGo to WASM module
    _compile_tinygo_module(ctx, tinygo, go_binary, wasm_opt_binary, wasm_tools, wasm_tools_toolchain, wasm_module, go_module_files)

    # Step 3: Convert module to component if needed
    _convert_to_component(ctx, wasm_tools, wasm_module, component_wasm)

    # Create provider - following Rust implementation pattern
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = ctx.attr.wit[WitInfo] if ctx.attr.wit else None,
        component_type = "component",
        imports = [],  # TODO: Parse from WIT
        exports = [ctx.attr.world] if ctx.attr.world else [],
        metadata = {
            "name": ctx.label.name,
            "language": "go",
            "target": "wasm32-wasip2",
            "tinygo_version": "0.38.0+",
        },
        profile = ctx.attr.optimization,
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm])),
    ]

def _prepare_go_module(ctx, tinygo_toolchain):
    """Prepare Go module structure using File Operations Component"""

    # Get WIT files from providers
    wit_file = None
    if ctx.attr.wit:
        wit_info = ctx.attr.wit[WitInfo]
        wit_files = wit_info.wit_files.to_list()
        if wit_files:
            wit_file = wit_files[0]  # Use first WIT file

    # Use the File Operations Component for workspace preparation
    module_dir = setup_go_module_action(
        ctx,
        sources = ctx.files.srcs,
        go_mod = ctx.file.go_mod,
        wit_file = wit_file,
    )

    return module_dir

def _compile_tinygo_module(ctx, tinygo, go_binary, wasm_opt_binary, wasm_tools, wasm_tools_toolchain, wasm_module, go_module_files):
    """Compile Go sources to WASM module using TinyGo - THE BAZEL WAY"""

    # Validate inputs
    if not ctx.files.srcs:
        fail("No Go source files provided for %s" % ctx.attr.name)

    # Check that TinyGo binary exists
    if not tinygo:
        fail("TinyGo toolchain binary not available for %s" % ctx.attr.name)

    # Create temp directory as declared output for TinyGo cache
    temp_cache_dir = ctx.actions.declare_directory(ctx.attr.name + "_tinygo_cache")

    # Create wrapper script that resolves absolute paths at runtime

    # Get toolchain for root path determination
    tinygo_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:tinygo_toolchain_type"]

    # Build TinyGo command arguments
    tinygo_args = [
        "build",
        "-target=wasip2",
        "-o",
        wasm_module.path,
    ]

    # Add optimization flags (now we have hermetic wasm-opt)
    if ctx.attr.optimization == "release":
        tinygo_args.extend(["-opt=2", "-no-debug"])  # Use full optimization with wasm-opt
    else:
        tinygo_args.extend(["-opt=1"])  # Use basic optimization for debug

    # Add WIT integration if available
    if ctx.attr.wit and ctx.attr.world:
        wit_info = ctx.attr.wit[WitInfo]
        wit_files = wit_info.wit_files.to_list()
        if wit_files:
            tinygo_args.extend([
                "-wit-package",
                wit_files[0].path,
                "-wit-world",
                ctx.attr.world,
            ])

    # Find main Go file path within the module directory
    main_go_found = False
    main_go_path = None
    for src in ctx.files.srcs:
        if src.basename == "main.go":
            main_go_path = go_module_files.path + "/main.go"
            main_go_found = True
            break

    if main_go_found:
        tinygo_args.append(main_go_path)
    else:
        # Check if there's at least one Go file
        go_files = [src for src in ctx.files.srcs if src.extension == "go"]
        if not go_files:
            fail("No Go source files found for %s" % ctx.attr.name)

        # Fallback: compile the entire Go module directory
        tinygo_args.append(go_module_files.path)
        print("Warning: No main.go found for %s, compiling entire module directory" % ctx.attr.name)

    # THE BAZEL WAY: Use Bazel's toolchain path resolution
    # Calculate TINYGOROOT from tinygo binary path dynamically
    tinygo_root_segments = tinygo.path.split("/")
    if len(tinygo_root_segments) >= 2:
        # Remove /bin/tinygo to get root directory
        tinygo_root = "/".join(tinygo_root_segments[:-2])
    else:
        # Fallback for unusual path structures
        tinygo_root = tinygo.dirname + "/.."

    # Validate that we have a reasonable TINYGOROOT path
    if not tinygo_root or tinygo_root == "":
        fail("Failed to determine TINYGOROOT from TinyGo binary path: %s" % tinygo.path)

    # Build PATH - hermetic toolchain approach
    # Include Go binary directory from Bazel's hermetic Go toolchain if available
    tool_paths = []
    if go_binary:
        go_bin_dir = go_binary.dirname
        tool_paths.append(go_bin_dir)
        print("DEBUG: Added Go binary directory to PATH: %s" % go_bin_dir)

    # Include wasm-opt binary directory from Binaryen
    if wasm_opt_binary:
        wasm_opt_bin_dir = wasm_opt_binary.dirname
        tool_paths.append(wasm_opt_bin_dir)
        print("DEBUG: Added wasm-opt binary directory to PATH: %s" % wasm_opt_bin_dir)

    # Include wasm-tools binary directory
    if wasm_tools:
        wasm_tools_bin_dir = wasm_tools.dirname
        tool_paths.append(wasm_tools_bin_dir)
        print("DEBUG: Added wasm-tools binary directory to PATH: %s" % wasm_tools_bin_dir)

    # THE BAZEL WAY: Build environment variables for TinyGo
    # No shell scripts needed - use ctx.actions.run() with environment
    
    # Build PATH environment variable
    path_env = _build_tool_path_env(ctx, tool_paths)
    
    # Build environment dictionary for TinyGo
    env = {
        "TINYGOROOT": tinygo_root,
        "GOCACHE": temp_cache_dir.path,  # Use Bazel's temp directory
        "CGO_ENABLED": "0",
        "GO111MODULE": "off",
        "GOPROXY": "direct",
        "HOME": temp_cache_dir.path,
        "TMPDIR": temp_cache_dir.path,
        "PATH": path_env,
    }
    
    # Add explicit Go binary path if available
    if go_binary:
        # Set GOROOT to help TinyGo find the Go installation  
        go_root = go_binary.dirname + "/.."  # Go binary is in bin/, so parent is GOROOT
        env["GOROOT"] = go_root
        # Also set the Go binary path directly - TinyGo can use this
        env["GOBIN"] = go_binary.dirname
        # Set the Go binary path for TinyGo to find
        env["GO"] = go_binary.path
        print("DEBUG: Set GOROOT to: %s" % go_root)
        print("DEBUG: Set GO to: %s" % go_binary.path)

    # Prepare inputs and tools - no wrapper script needed!
    inputs = [go_module_files, tinygo, wasm_tools]
    tools = []
    if go_binary:
        # Go binary should be a tool (executable) not just an input
        tools.append(go_binary)
    if wasm_opt_binary:
        inputs.append(wasm_opt_binary)

    # Include TinyGo toolchain files for complete environment
    if hasattr(tinygo_toolchain, "tinygo_files") and tinygo_toolchain.tinygo_files:
        inputs.extend(tinygo_toolchain.tinygo_files.files.to_list())

    # Include Binaryen files for wasm-opt
    if hasattr(tinygo_toolchain, "binaryen_files") and tinygo_toolchain.binaryen_files:
        inputs.extend(tinygo_toolchain.binaryen_files.files.to_list())

    # Include wasm-tools files
    if hasattr(wasm_tools_toolchain, "wasm_tools_files") and wasm_tools_toolchain.wasm_tools_files:
        inputs.extend(wasm_tools_toolchain.wasm_tools_files.files.to_list())

    if ctx.attr.wit:
        wit_info = ctx.attr.wit[WitInfo]
        inputs.extend(wit_info.wit_files.to_list())

    # THE BAZEL WAY: Direct execution with environment variables
    ctx.actions.run(
        executable = tinygo,
        arguments = tinygo_args,
        inputs = inputs,
        tools = tools,
        outputs = [wasm_module, temp_cache_dir],
        mnemonic = "TinyGoCompile",
        progress_message = "Compiling %s with TinyGo" % ctx.attr.name,
        env = env,
        use_default_shell_env = False,
        execution_requirements = {
            "local": "1",  # TinyGo requires local execution
        },
    )

def _convert_to_component(ctx, wasm_tools, wasm_module, component_wasm):
    """Convert WASM module to component using wasm-tools - THE BAZEL WAY"""

    # For TinyGo wasip2 target, output is already a component
    # THE BAZEL WAY: Use Bazel-native symlink instead of system cp command
    ctx.actions.symlink(
        output = component_wasm,
        target_file = wasm_module,
    )

# Rule definition - following Rust pattern
go_wasm_component = rule(
    implementation = _go_wasm_component_impl,
    cfg = wasm_transition,  # Use same transition as Rust
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = "Go source files",
            mandatory = True,
        ),
        "go_mod": attr.label(
            allow_single_file = ["go.mod"],
            doc = "Go module file",
        ),
        "wit": attr.label(
            providers = [WitInfo],
            doc = "WIT library for binding generation",
        ),
        "world": attr.string(
            doc = "WIT world name to implement",
        ),
        "adapter": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASI adapter for component transformation",
        ),
        "optimization": attr.string(
            doc = "Optimization level: 'debug' or 'release'",
            default = "release",
            values = ["debug", "release"],
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:tinygo_toolchain_type",
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """Builds a WebAssembly component from Go source using TinyGo + WASI Preview 2.

This rule provides state-of-the-art Go support for WebAssembly Component Model:
- Uses TinyGo v0.38.0+ with native WASI Preview 2 support
- Cross-platform Bazel implementation (Windows/macOS/Linux)
- Hermetic builds with proper toolchain integration
- WIT binding generation support
- Zero shell script dependencies

Example:
    go_wasm_component(
        name = "http_downloader",
        srcs = ["main.go", "client.go"],
        go_mod = "go.mod",
        wit = "//wit:http_interfaces",
        world = "http-client",
        optimization = "release",
    )
""",
)

def go_wit_bindgen(**kwargs):
    """Generate Go bindings from WIT files - integrated with go_wasm_component.

    This function exists for backward compatibility with existing examples.
    WIT binding generation is now handled automatically by go_wasm_component rule.

    For new code, use go_wasm_component directly with wit and world attributes.
    """
    native.genrule(
        name = kwargs.get("name", "wit_bindings"),
        outs = [kwargs.get("name", "wit_bindings") + "_generated.go"],
        cmd = """
echo '// WIT bindings are generated automatically by go_wasm_component rule' > $@
echo '// This placeholder exists for backward compatibility' >> $@
echo '// Use go_wasm_component with wit and world attributes for actual binding generation' >> $@
        """,
        visibility = ["//visibility:public"],
    )
