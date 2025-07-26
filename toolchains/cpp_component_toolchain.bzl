"""C/C++ WebAssembly component toolchain definitions for Preview2"""

load("//toolchains:tool_versions.bzl", "get_tool_info")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error", "validate_system_tool")
load("//toolchains:tool_cache.bzl", "retrieve_cached_tool", "cache_tool", "validate_tool_functionality")

def _cpp_component_toolchain_impl(ctx):
    """Implementation of cpp_component_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        clang = ctx.file.clang,
        clang_cpp = ctx.file.clang_cpp,
        llvm_ar = ctx.file.llvm_ar,
        wit_bindgen = ctx.file.wit_bindgen,
        wasm_tools = ctx.file.wasm_tools,
        sysroot = ctx.file.sysroot,
        crt_objects = ctx.files.crt_objects,
        include_dirs = ctx.files.include_dirs,
    )

    return [toolchain_info]

cpp_component_toolchain = rule(
    implementation = _cpp_component_toolchain_impl,
    attrs = {
        "clang": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Clang C compiler binary",
        ),
        "clang_cpp": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Clang C++ compiler binary",
        ),
        "llvm_ar": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "LLVM archiver binary",
        ),
        "wit_bindgen": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen binary for generating C/C++ bindings",
        ),
        "wasm_tools": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-tools binary for component creation",
        ),
        "sysroot": attr.label(
            allow_single_file = True,
            doc = "WASI SDK sysroot directory",
        ),
        "crt_objects": attr.label_list(
            allow_files = [".o"],
            doc = "C runtime object files",
        ),
        "include_dirs": attr.label_list(
            allow_files = True,
            doc = "System include directories",
        ),
    },
    doc = "Declares a C/C++ WebAssembly component toolchain",
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

def _cpp_component_toolchain_repository_impl(repository_ctx):
    """Create C/C++ component toolchain repository"""

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)
    wasi_sdk_version = repository_ctx.attr.wasi_sdk_version

    if strategy == "system":
        _setup_system_cpp_tools(repository_ctx)
    elif strategy == "download":
        _setup_downloaded_cpp_tools(repository_ctx, platform, wasi_sdk_version)
    elif strategy == "build":
        _setup_built_cpp_tools(repository_ctx)
    else:
        fail(format_diagnostic_error(
            "E001",
            "Unknown C/C++ strategy: {}".format(strategy),
            "Must be 'system', 'download', or 'build'"
        ))

    # Create BUILD files
    _create_cpp_build_files(repository_ctx)

def _setup_system_cpp_tools(repository_ctx):
    """Set up system-installed C/C++ tools"""

    # Validate system tools
    tools = [
        ("clang", "clang"),
        ("clang++", "clang++"), 
        ("llvm-ar", "llvm-ar"),
        ("wit-bindgen", "wit-bindgen"),
        ("wasm-tools", "wasm-tools")
    ]
    
    for tool_name, binary_name in tools:
        validation_result = validate_system_tool(repository_ctx, binary_name)
        
        if not validation_result["valid"]:
            if tool_name in ["clang", "clang++"]:
                fail(format_diagnostic_error(
                    "E006",
                    "{} not found in system PATH".format(binary_name),
                    "Install WASI SDK or LLVM with WebAssembly support"
                ))
            else:
                fail(validation_result["error"])
        
        if "warning" in validation_result:
            print(validation_result["warning"])
        
        # Create wrapper executable
        output_name = "clang_cpp" if tool_name == "clang++" else tool_name.replace("-", "_")
        repository_ctx.file(output_name, """#!/bin/bash
exec {} "$@"
""".format(binary_name), executable = True)
        
        print("Using system {}: {} at {}".format(
            tool_name, binary_name,
            validation_result.get("path", "system PATH")
        ))

    # Set up sysroot (assume system WASI SDK)
    _setup_system_sysroot(repository_ctx)

def _setup_downloaded_cpp_tools(repository_ctx, platform, wasi_sdk_version):
    """Download WASI SDK and related tools"""

    # Download WASI SDK
    wasi_sdk_url = _get_wasi_sdk_url(platform, wasi_sdk_version)
    wasi_sdk_dir = "wasi-sdk-{}".format(wasi_sdk_version)
    
    print("Downloading WASI SDK version {} for platform {}".format(wasi_sdk_version, platform))
    
    # Download WASI SDK
    result = repository_ctx.download_and_extract(
        url = wasi_sdk_url,
        stripPrefix = wasi_sdk_dir,
    )
    
    if not result.success:
        fail(format_diagnostic_error(
            "E003", 
            "Failed to download WASI SDK from {}".format(wasi_sdk_url),
            "Check network connectivity or try system strategy"
        ))
    
    # Create tool wrappers pointing to downloaded WASI SDK
    _create_wasi_sdk_wrappers(repository_ctx, wasi_sdk_dir)
    
    print("Successfully downloaded WASI SDK")

    # Set up wit-bindgen and wasm-tools (assume system or use existing toolchain)
    _setup_component_tools(repository_ctx)

def _setup_built_cpp_tools(repository_ctx):
    """Build C/C++ tools from source"""
    
    # This would involve building LLVM/Clang with WebAssembly support
    # For now, fall back to system strategy
    print("Build strategy not yet implemented for C/C++ toolchain, using system tools")
    _setup_system_cpp_tools(repository_ctx)

def _get_wasi_sdk_url(platform, version):
    """Get WASI SDK download URL for platform and version"""
    
    # WASI SDK release URL format
    base_url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{}"
    
    platform_map = {
        "linux_amd64": "linux",
        "linux_arm64": "linux",  # Use same binary for now
        "darwin_amd64": "macos",
        "darwin_arm64": "macos",
        "windows_amd64": "mingw"
    }
    
    os_name = platform_map.get(platform, "linux")
    filename = "wasi-sdk-{}-{}.tar.gz".format(version, os_name)
    
    return base_url.format(version) + "/" + filename

def _create_wasi_sdk_wrappers(repository_ctx, wasi_sdk_dir):
    """Create wrapper scripts for WASI SDK tools"""
    
    # Clang wrapper with Preview2 target
    repository_ctx.file("clang", """#!/bin/bash
exec ./bin/clang \\
  --target=wasm32-wasip2 \\
  --sysroot=./share/wasi-sysroot \\
  -D_WASI_EMULATED_PROCESS_CLOCKS \\
  -D_WASI_EMULATED_SIGNAL \\
  -D_WASI_EMULATED_MMAN \\
  "$@"
""", executable = True)

    # Clang++ wrapper with Preview2 target and C++ support
    repository_ctx.file("clang_cpp", """#!/bin/bash
exec ./bin/clang++ \\
  --target=wasm32-wasip2 \\
  --sysroot=./share/wasi-sysroot \\
  -D_WASI_EMULATED_PROCESS_CLOCKS \\
  -D_WASI_EMULATED_SIGNAL \\
  -D_WASI_EMULATED_MMAN \\
  -fno-exceptions \\
  -fno-rtti \\
  "$@"
""", executable = True)

    # LLVM AR wrapper
    repository_ctx.file("llvm_ar", """#!/bin/bash
exec ./bin/llvm-ar "$@"
""", executable = True)

def _setup_component_tools(repository_ctx):
    """Set up wit-bindgen and wasm-tools"""
    
    # Assume these are available from system or existing toolchain
    for tool in ["wit_bindgen", "wasm_tools"]:
        validation_result = validate_system_tool(repository_ctx, tool.replace("_", "-"))
        
        if not validation_result["valid"]:
            fail(format_diagnostic_error(
                "E006",
                "{} not found".format(tool.replace("_", "-")),
                "Configure wasm_toolchain extension first"
            ))
        
        repository_ctx.file(tool, """#!/bin/bash
exec {} "$@"
""".format(tool.replace("_", "-")), executable = True)

def _setup_system_sysroot(repository_ctx):
    """Set up system sysroot directory"""
    
    # Try to find WASI SDK sysroot
    possible_locations = [
        "/opt/wasi-sdk/share/wasi-sysroot",
        "/usr/local/share/wasi-sysroot",
        "/usr/share/wasi-sysroot",
    ]
    
    for location in possible_locations:
        result = repository_ctx.execute(["test", "-d", location])
        if result.return_code == 0:
            # Create symlink to sysroot
            repository_ctx.symlink(location, "sysroot")
            print("Using WASI sysroot at: {}".format(location))
            return
    
    # If not found, create minimal sysroot structure
    print("Warning: WASI sysroot not found, creating minimal structure")
    repository_ctx.execute(["mkdir", "-p", "sysroot/include"])
    repository_ctx.execute(["mkdir", "-p", "sysroot/lib"])

def _create_cpp_build_files(repository_ctx):
    """Create BUILD files for C/C++ toolchain"""

    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:cpp_component_toolchain.bzl", "cpp_component_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables
filegroup(
    name = "clang_binary",
    srcs = ["clang"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "clang_cpp_binary",
    srcs = ["clang_cpp"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_ar_binary",
    srcs = ["llvm_ar"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wit_bindgen_binary",
    srcs = ["wit_bindgen"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wasm_tools_binary", 
    srcs = ["wasm_tools"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "sysroot_files",
    srcs = glob(["sysroot/**/*"]),
    visibility = ["//visibility:public"],
)

# Toolchain implementation
cpp_component_toolchain(
    name = "cpp_component_toolchain_impl",
    clang = ":clang_binary",
    clang_cpp = ":clang_cpp_binary",
    llvm_ar = ":llvm_ar_binary",
    wit_bindgen = ":wit_bindgen_binary",
    wasm_tools = ":wasm_tools_binary",
    sysroot = "sysroot",
    include_dirs = glob(["sysroot/include/**/*"]),
)

# Toolchain registration
toolchain(
    name = "cpp_component_toolchain",
    toolchain = ":cpp_component_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:cpp_component_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Alias for toolchain registration
alias(
    name = "all",
    actual = ":cpp_component_toolchain",
    visibility = ["//visibility:public"],
)
""")

cpp_component_toolchain_repository = repository_rule(
    implementation = _cpp_component_toolchain_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'system', 'download', or 'build'",
            default = "system",
            values = ["system", "download", "build"],
        ),
        "wasi_sdk_version": attr.string(
            doc = "WASI SDK version to use",
            default = "24",
        ),
    },
)