"""Bazel rules for Go WebAssembly components"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _go_component_impl(ctx):
    """Implementation of go_component rule"""

    # Get Go toolchain
    go_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:go_wasm_toolchain_type"]
    go = go_toolchain.go
    wit_bindgen_go = go_toolchain.wit_bindgen_go
    wasm_tools = go_toolchain.wasm_tools

    # Output files
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")
    
    # Input files
    go_sources = ctx.files.srcs
    wit_file = ctx.file.wit
    go_mod = ctx.file.go_mod

    # Generate bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate Go bindings from WIT
    wit_args = ctx.actions.args()
    wit_args.add("generate")
    wit_args.add("--out", bindings_dir.path)
    wit_args.add("--package", ctx.attr.go_package)
    
    if ctx.attr.world:
        wit_args.add("--world", ctx.attr.world)
    
    wit_args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen_go,
        arguments = [wit_args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = "WitBindgenGo",
        progress_message = "Generating Go bindings for %s" % ctx.label,
    )

    # Create working directory for Go build
    work_dir = ctx.actions.declare_directory(ctx.attr.name + "_work")

    # Prepare Go module and sources
    prep_script = ctx.actions.declare_file(ctx.attr.name + "_prep.sh")
    prep_content = """#!/bin/bash
set -e

WORK_DIR="{work_dir}"
BINDINGS_DIR="{bindings_dir}"
GO_PACKAGE="{go_package}"

# Create working directory structure
mkdir -p "$WORK_DIR"

# Copy go.mod
if [ -f "{go_mod}" ]; then
    cp "{go_mod}" "$WORK_DIR/go.mod"
else
    # Generate basic go.mod
    cat > "$WORK_DIR/go.mod" << EOF
module $GO_PACKAGE

go 1.21

require (
    github.com/bytecodealliance/wasm-tools-go v0.1.1
)
EOF
fi

# Copy Go source files
{copy_sources}

# Copy generated bindings
if [ -d "$BINDINGS_DIR" ]; then
    cp -r "$BINDINGS_DIR"/* "$WORK_DIR/"
fi

echo "Prepared Go component sources in $WORK_DIR"
""".format(
        work_dir = work_dir.path,
        bindings_dir = bindings_dir.path,
        go_package = ctx.attr.go_package,
        go_mod = go_mod.path if go_mod else "",
        copy_sources = "\n".join([
            'cp "{}" "$WORK_DIR/{}"'.format(src.path, src.basename)
            for src in go_sources
        ]),
    )

    ctx.actions.write(
        output = prep_script,
        content = prep_content,
        is_executable = True,
    )

    # Run preparation
    ctx.actions.run(
        executable = prep_script,
        inputs = [bindings_dir] + go_sources + ([go_mod] if go_mod else []),
        outputs = [work_dir],
        mnemonic = "PrepareGoComponent",
        progress_message = "Preparing Go component sources for %s" % ctx.label,
    )

    # Build WASM binary
    wasm_binary = ctx.actions.declare_file(ctx.attr.name + ".wasm")
    
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build.sh")
    build_content = """#!/bin/bash
set -e

WORK_DIR="{work_dir}"
OUTPUT="{output}"
MAIN_FILE="{main_file}"

cd "$WORK_DIR"

# Set Go environment for WASM compilation
export GOOS=wasip1
export GOARCH=wasm
export CGO_ENABLED=0

# Build the WASM binary
{go_path} build -o "$OUTPUT" "$MAIN_FILE"

echo "Built Go component WASM binary: $OUTPUT"
""".format(
        work_dir = work_dir.path,
        output = wasm_binary.path,
        main_file = ctx.attr.main_file,
        go_path = go.path,
    )

    ctx.actions.write(
        output = build_script,
        content = build_content,
        is_executable = True,
    )

    ctx.actions.run(
        executable = build_script,
        inputs = [work_dir],
        outputs = [wasm_binary],
        mnemonic = "BuildGoWasm",  
        progress_message = "Building Go WASM binary for %s" % ctx.label,
    )

    # Convert WASM binary to component using wasm-tools
    component_args = ctx.actions.args()
    component_args.add("component")
    component_args.add("new")
    component_args.add(wasm_binary.path)
    component_args.add("--wit", wit_file.path)
    component_args.add("--output", component_wasm.path)
    
    if ctx.attr.world:
        component_args.add("--world", ctx.attr.world)

    ctx.actions.run(
        executable = wasm_tools,
        arguments = [component_args],
        inputs = [wasm_binary, wit_file],
        outputs = [component_wasm],
        mnemonic = "CreateGoComponent",
        progress_message = "Creating WebAssembly component for %s" % ctx.label,
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
        OutputGroupInfo(
            bindings = depset([bindings_dir]),
            wasm_binary = depset([wasm_binary]),
        ),
    ]

go_component = rule(
    implementation = _go_component_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            mandatory = True,
            doc = "Go source files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies (other Go libraries or components)",
        ),
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "go_mod": attr.label(
            allow_single_file = ["go.mod"],
            doc = "go.mod file (auto-generated if not provided)",
        ),
        "main_file": attr.string(
            default = "main.go",
            doc = "Main Go file to build",
        ),
        "go_package": attr.string(
            mandatory = True,
            doc = "Go module package name",
        ),
        "world": attr.string(
            doc = "WIT world to target (optional)",
        ),
        "package_name": attr.string(
            doc = "WIT package name (auto-generated if not provided)",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:go_wasm_toolchain_type"],
    doc = """
    Builds a WebAssembly component from Go source code.
    
    This rule compiles Go code to WASM and wraps it as a WebAssembly component
    that implements the specified WIT interface.
    
    Example:
        go_component(
            name = "my_go_component",
            srcs = [
                "main.go",
                "handlers.go",
            ],
            wit = "component.wit",
            go_package = "github.com/myorg/mycomponent",
            main_file = "main.go",
            world = "my-world",
        )
    """,
)

def _go_wit_bindgen_impl(ctx):
    """Implementation of go_wit_bindgen rule"""

    # Get Go toolchain
    go_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:go_wasm_toolchain_type"]
    wit_bindgen_go = go_toolchain.wit_bindgen_go

    # Input WIT file
    wit_file = ctx.file.wit

    # Output bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate Go bindings
    args = ctx.actions.args()
    args.add("generate")
    args.add("--out", bindings_dir.path)
    args.add("--package", ctx.attr.go_package)
    
    if ctx.attr.world:
        args.add("--world", ctx.attr.world)
    
    if ctx.attr.out_dir:
        args.add("--out-dir", ctx.attr.out_dir)
    
    args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen_go,
        arguments = [args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = "GoWitBindgen",
        progress_message = "Generating Go WIT bindings for %s" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([bindings_dir])),
        OutputGroupInfo(
            bindings = depset([bindings_dir]),
        ),
    ]

go_wit_bindgen = rule(
    implementation = _go_wit_bindgen_impl,
    attrs = {
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "go_package": attr.string(
            mandatory = True,
            doc = "Go package name for generated bindings",
        ),
        "world": attr.string(
            doc = "WIT world to generate bindings for",
        ),
        "out_dir": attr.string(
            doc = "Output directory name within bindings",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:go_wasm_toolchain_type"],
    doc = """
    Generates Go bindings from WIT interface definitions.
    
    This rule uses wit-bindgen-go to create Go code that implements
    or consumes WIT interfaces.
    
    Example:
        go_wit_bindgen(
            name = "component_bindings",
            wit = "component.wit",
            go_package = "github.com/myorg/bindings",
            world = "my-world",
        )
    """,
)

def _go_mod_download_impl(ctx):
    """Implementation of go_mod_download rule for managing Go dependencies"""

    # Get Go toolchain
    go_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:go_wasm_toolchain_type"]
    go = go_toolchain.go

    # Input go.mod file
    go_mod = ctx.file.go_mod

    # Output directory for downloaded modules
    mod_cache = ctx.actions.declare_directory("go_mod_cache")

    # Download script
    download_script = ctx.actions.declare_file(ctx.attr.name + "_download.sh")
    download_content = """#!/bin/bash
set -e

GO_MOD="{go_mod}"
MOD_CACHE="{mod_cache}"
GO_PATH="{go_path}"

# Create working directory
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Copy go.mod to working directory
cp "$GO_MOD" "$WORK_DIR/go.mod"

# Create go.sum if it doesn't exist
touch "$WORK_DIR/go.sum"

cd "$WORK_DIR"

# Set Go environment
export GOPATH="$MOD_CACHE"
export GOPROXY=direct
export GOSUMDB=sum.golang.org

# Download dependencies
"$GO_PATH" mod download

# Copy downloaded modules to output
mkdir -p "$MOD_CACHE"
if [ -d "$GOPATH/pkg/mod" ]; then
    cp -r "$GOPATH/pkg/mod"/* "$MOD_CACHE/" || true
fi

echo "Go module dependencies downloaded successfully"
""".format(
        go_mod = go_mod.path,
        mod_cache = mod_cache.path,
        go_path = go.path,
    )

    ctx.actions.write(
        output = download_script,
        content = download_content,
        is_executable = True,
    )

    ctx.actions.run(
        executable = download_script,
        inputs = [go_mod],
        outputs = [mod_cache],
        mnemonic = "GoModDownload",
        progress_message = "Downloading Go module dependencies for %s" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([mod_cache])),
        OutputGroupInfo(
            mod_cache = depset([mod_cache]),
        ),
    ]

go_mod_download = rule(
    implementation = _go_mod_download_impl,
    attrs = {
        "go_mod": attr.label(
            allow_single_file = ["go.mod"],
            mandatory = True,
            doc = "go.mod file with dependencies",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:go_wasm_toolchain_type"],
    doc = """
    Downloads Go module dependencies specified in go.mod.
    
    This rule runs 'go mod download' to fetch dependencies,
    making them available for Go component builds.
    
    Example:
        go_mod_download(
            name = "go_deps",
            go_mod = "go.mod",
        )
    """,
)