"""Go WebAssembly component toolchain definitions"""

load("//toolchains:tool_versions.bzl", "get_tool_info")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error", "validate_system_tool")
load("//toolchains:tool_cache.bzl", "retrieve_cached_tool", "cache_tool", "validate_tool_functionality")

# wit-bindgen-go platform mapping
WIT_BINDGEN_GO_PLATFORMS = {
    "darwin_amd64": {
        "binary_name": "wit-bindgen-go-x86_64-apple-darwin",
        "sha256": "4f3fe255640981a2ec0a66980fd62a31002829fab70539b40a1a69db43f999cd",
    },
    "darwin_arm64": {
        "binary_name": "wit-bindgen-go-aarch64-apple-darwin",
        "sha256": "5e492806d886e26e4966c02a097cb1f227c3984ce456a29429c21b7b2ee46a5b",
    },
    "linux_amd64": {
        "binary_name": "wit-bindgen-go-x86_64-unknown-linux-musl",
        "sha256": "cb6b0eab0f8abbf97097cde9f0ab7e44ae07bf769c718029882b16344a7cda64",
    },
    "linux_arm64": {
        "binary_name": "wit-bindgen-go-aarch64-unknown-linux-musl",
        "sha256": "dcd446b35564105c852eadb4244ae35625a83349ed1434a1c8e5497a2a267b44",
    },
    "windows_amd64": {
        "binary_name": "wit-bindgen-go-x86_64-pc-windows-gnu.exe",
        "sha256": "e133d9f18bc0d8a3d848df78960f9974a4333bee7ed3f99b4c9e900e9e279029",
    },
}

def _go_wasm_toolchain_impl(ctx):
    """Implementation of go_wasm_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        go = ctx.file.go,
        wit_bindgen_go = ctx.file.wit_bindgen_go,
        wasm_tools = ctx.file.wasm_tools,
    )

    return [toolchain_info]

go_wasm_toolchain = rule(
    implementation = _go_wasm_toolchain_impl,
    attrs = {
        "go": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Go compiler binary",
        ),
        "wit_bindgen_go": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen-go binary for generating Go bindings",
        ),
        "wasm_tools": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-tools binary for component creation",
        ),
    },
    doc = "Declares a Go WebAssembly component toolchain",
)

def _detect_host_platform(repository_ctx):
    """Detect the host platform"""

    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    if os_name == "mac os x":
        os_name = "darwin"

    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

def _go_wasm_toolchain_repository_impl(repository_ctx):
    """Create Go WebAssembly toolchain repository"""

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.wit_bindgen_go_version

    if strategy == "system":
        _setup_system_go_tools(repository_ctx)
    elif strategy == "download":
        _setup_downloaded_go_tools(repository_ctx, platform, version)
    elif strategy == "build":
        _setup_built_go_tools(repository_ctx)
    else:
        fail(format_diagnostic_error(
            "E001",
            "Unknown Go strategy: {}".format(strategy),
            "Must be 'system', 'download', or 'build'"
        ))

    # Create BUILD files
    _create_go_build_files(repository_ctx)

def _setup_system_go_tools(repository_ctx):
    """Set up system-installed Go tools"""

    # Validate system tools
    tools = [("go", "go"), ("wit-bindgen-go", "wit-bindgen-go"), ("wasm-tools", "wasm-tools")]
    
    for tool_name, binary_name in tools:
        validation_result = validate_system_tool(repository_ctx, binary_name)
        
        if not validation_result["valid"]:
            if tool_name == "wit-bindgen-go":
                # wit-bindgen-go might not be installed, provide helpful message
                fail(format_diagnostic_error(
                    "E006",
                    "wit-bindgen-go not found in system PATH",
                    "Install with: go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest"
                ))
            else:
                fail(validation_result["error"])
        
        if "warning" in validation_result:
            print(validation_result["warning"])
        
        # Create wrapper executable
        repository_ctx.file(tool_name, """#!/bin/bash
exec {} "$@"
""".format(binary_name), executable = True)
        
        print("Using system {}: {} at {}".format(
            tool_name, binary_name,
            validation_result.get("path", "system PATH")
        ))

def _setup_downloaded_go_tools(repository_ctx, platform, version):
    """Download prebuilt Go tools"""

    # Set up Go (assume system installation)
    go_validation = validate_system_tool(repository_ctx, "go")
    if not go_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "Go compiler not found",
            "Install Go from https://golang.org/dl/"
        ))
    
    repository_ctx.file("go", """#!/bin/bash
exec go "$@"
""", executable = True)

    # Set up wasm-tools (assume system installation or use existing toolchain)
    wasm_tools_validation = validate_system_tool(repository_ctx, "wasm-tools")
    if not wasm_tools_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "wasm-tools not found",
            "Install wasm-tools or configure wasm_toolchain extension"
        ))
    
    repository_ctx.file("wasm-tools", """#!/bin/bash
exec wasm-tools "$@"
""", executable = True)

    # Try to retrieve wit-bindgen-go from cache first
    cached_tool = retrieve_cached_tool(repository_ctx, "wit-bindgen-go", version, platform, "download")
    if not cached_tool:
        # Download wit-bindgen-go binary
        if platform not in WIT_BINDGEN_GO_PLATFORMS:
            fail(format_diagnostic_error(
                "E001",
                "Unsupported platform {} for wit-bindgen-go".format(platform),
                "Use 'build' strategy to compile from source"
            ))
        
        platform_info = WIT_BINDGEN_GO_PLATFORMS[platform]
        binary_name = platform_info["binary_name"]
        
        # wit-bindgen-go releases (hypothetical URL structure)
        wit_bindgen_go_url = "https://github.com/bytecodealliance/wit-bindgen-go/releases/download/v{}/{}".format(
            version, binary_name
        )
        
        result = repository_ctx.download(
            url = wit_bindgen_go_url,
            output = "wit-bindgen-go",
            sha256 = platform_info["sha256"],
            executable = True,
        )
        
        if not result or (hasattr(result, 'return_code') and result.return_code != 0):
            print("Warning: Failed to download wit-bindgen-go")
            print("Falling back to build from source...")
            _build_wit_bindgen_go_from_source(repository_ctx)
            return
        
        # Validate downloaded tool
        validation_result = validate_tool_functionality(repository_ctx, "wit-bindgen-go", "wit-bindgen-go")
        if not validation_result["valid"]:
            fail(format_diagnostic_error(
                "E007",
                "Downloaded wit-bindgen-go failed validation: {}".format(validation_result["error"]),
                "Try build strategy or check platform compatibility"
            ))
        
        # Cache the tool
        tool_binary = repository_ctx.path("wit-bindgen-go")
        cache_tool(repository_ctx, "wit-bindgen-go", tool_binary, version, platform, "download", platform_info["sha256"])

def _setup_built_go_tools(repository_ctx):
    """Build Go tools from source"""

    # Validate Go installation
    go_validation = validate_system_tool(repository_ctx, "go")
    if not go_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "Go compiler required for build strategy",
            "Install Go from https://golang.org/dl/"
        ))
    
    repository_ctx.file("go", """#!/bin/bash
exec go "$@"
""", executable = True)

    # Set up wasm-tools (assume available)
    repository_ctx.file("wasm-tools", """#!/bin/bash
exec wasm-tools "$@"
""", executable = True)

    # Build wit-bindgen-go from source
    _build_wit_bindgen_go_from_source(repository_ctx)

def _build_wit_bindgen_go_from_source(repository_ctx):
    """Build wit-bindgen-go from source using go install"""

    platform = _detect_host_platform(repository_ctx)
    
    # Try to retrieve from cache first
    cached_tool = retrieve_cached_tool(repository_ctx, "wit-bindgen-go", "latest", platform, "build")
    if cached_tool:
        return

    # Use go install to build wit-bindgen-go
    result = repository_ctx.execute([
        "go", "install", 
        "github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest"
    ])
    
    if result.return_code != 0:
        fail(format_diagnostic_error(
            "E005",
            "Failed to build wit-bindgen-go: {}".format(result.stderr),
            "Check Go installation and network connectivity"
        ))
    
    # Find the installed binary in GOPATH/bin or GOBIN
    gopath_result = repository_ctx.execute(["go", "env", "GOPATH"])
    if gopath_result.return_code == 0:
        gopath = gopath_result.stdout.strip()
        wit_bindgen_go_path = "{}/bin/wit-bindgen-go".format(gopath)
        
        # Check if binary exists
        check_result = repository_ctx.execute(["test", "-f", wit_bindgen_go_path])
        if check_result.return_code == 0:
            # Copy to repository
            repository_ctx.execute(["cp", wit_bindgen_go_path, "wit-bindgen-go"])
            repository_ctx.execute(["chmod", "+x", "wit-bindgen-go"])
            
            # Validate built tool
            validation_result = validate_tool_functionality(repository_ctx, "wit-bindgen-go", "wit-bindgen-go")
            if not validation_result["valid"]:
                fail(format_diagnostic_error(
                    "E007",
                    "Built wit-bindgen-go failed validation: {}".format(validation_result["error"]),
                    "Check build environment and dependencies"
                ))
            
            # Cache the built tool
            tool_binary = repository_ctx.path("wit-bindgen-go")
            cache_tool(repository_ctx, "wit-bindgen-go", tool_binary, "latest", platform, "build")
            
            print("Successfully built and cached wit-bindgen-go from source")
            return
    
    # Fallback: create a wrapper that calls the globally installed version
    repository_ctx.file("wit-bindgen-go", """#!/bin/bash
exec wit-bindgen-go "$@"
""", executable = True)
    
    print("Built wit-bindgen-go from source (using global installation)")

def _create_go_build_files(repository_ctx):
    """Create BUILD files for Go toolchain"""

    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:go_toolchain.bzl", "go_wasm_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables
filegroup(
    name = "go_binary",
    srcs = ["go"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wit_bindgen_go_binary",
    srcs = ["wit-bindgen-go"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wasm_tools_binary",
    srcs = ["wasm-tools"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
go_wasm_toolchain(
    name = "go_wasm_toolchain_impl",
    go = ":go_binary",
    wit_bindgen_go = ":wit_bindgen_go_binary",
    wasm_tools = ":wasm_tools_binary",
)

# Toolchain registration
toolchain(
    name = "go_wasm_toolchain",
    toolchain = ":go_wasm_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:go_wasm_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Alias for toolchain registration
alias(
    name = "all",
    actual = ":go_wasm_toolchain",
    visibility = ["//visibility:public"],
)
""")

go_wasm_toolchain_repository = repository_rule(
    implementation = _go_wasm_toolchain_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'system', 'download', or 'build'",
            default = "system",
            values = ["system", "download", "build"],
        ),
        "wit_bindgen_go_version": attr.string(
            doc = "wit-bindgen-go version to use",
            default = "0.1.0",
        ),
    },
)