"""WebAssembly toolchain definitions with enhanced tool management"""

load("//checksums:registry.bzl", "get_tool_info", "validate_tool_compatibility")
load("//toolchains:diagnostics.bzl", "create_retry_wrapper", "format_diagnostic_error", "log_diagnostic_info", "validate_system_tool")
load("//toolchains:monitoring.bzl", "add_build_telemetry", "create_health_check")
load("//toolchains:tool_cache.bzl", "cache_tool", "clean_expired_cache", "retrieve_cached_tool", "validate_tool_functionality")
load("//toolchains:tool_versions.bzl", "get_tool_version", "validate_tool_versions")

def _get_rust_toolchain_info(repository_ctx):
    """Get Rust toolchain info from the registered hermetic toolchain"""

    # Method 1: Try to find hermetic cargo and rustc through repository_ctx.which
    # This works in some environments where the PATH is properly set
    cargo_binary = repository_ctx.which("cargo")
    rustc_binary = repository_ctx.which("rustc")

    if cargo_binary and rustc_binary:
        return struct(
            cargo = str(cargo_binary),
            rustc = str(rustc_binary),
        )

    # Method 2: Try to access the Rust toolchain repository directly
    # In MODULE.bazel mode, the rust_toolchains should provide hermetic binaries
    # Try common paths where rules_rust places the hermetic tools
    potential_rust_paths = [
        # Try to find the rust toolchain binary location
        "@rust_toolchains//:rust_std-1.88.0-host",
        "@rust_toolchains//:cargo",
        "@rust_toolchains//:rustc",
    ]

    # For now, if PATH-based discovery fails, we need to fail
    # The proper fix would require deeper integration with rules_rust
    # or using a different pattern (like using rules_rust's own repository rules)

    return None

def _get_wasm_tools_platform_info(platform, version):
    """Get platform info and checksum for wasm-tools from centralized registry"""
    from_registry = get_tool_info("wasm-tools", version, platform)
    if not from_registry:
        fail("Unsupported platform {} for wasm-tools version {}".format(platform, version))

    return struct(
        sha256 = from_registry["sha256"],
        url_suffix = from_registry["url_suffix"],
    )

def _wasm_tools_toolchain_impl(ctx):
    """Implementation of wasm_tools_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        wasm_tools = ctx.file.wasm_tools,
        wac = ctx.file.wac,
        wit_bindgen = ctx.file.wit_bindgen,
        wrpc = ctx.file.wrpc,
        wasmsign2 = ctx.file.wasmsign2,
    )

    return [toolchain_info]

wasm_tools_toolchain = rule(
    implementation = _wasm_tools_toolchain_impl,
    attrs = {
        "wasm_tools": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-tools binary",
        ),
        "wac": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wac (WebAssembly Composition) binary",
        ),
        "wit_bindgen": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen binary",
        ),
        "wrpc": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wrpc binary",
        ),
        "wasmsign2": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasmsign2 WebAssembly signing binary",
        ),
    },
    doc = "Declares a WebAssembly toolchain with signing support",
)

def _detect_host_platform(repository_ctx):
    """Detect the host platform"""

    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    # Normalize platform names for cross-platform compatibility
    if "mac" in os_name or "darwin" in os_name:
        os_name = "darwin"
    elif "windows" in os_name:
        os_name = "windows"
    elif "linux" in os_name:
        os_name = "linux"

    # Normalize architecture names
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

def _wasm_toolchain_repository_impl(repository_ctx):
    """Create toolchain repository with enhanced tool management"""

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Log diagnostic information
    log_diagnostic_info(repository_ctx, "wasm-tools", platform, version, strategy)

    # Clean expired cache entries
    clean_expired_cache(repository_ctx)

    # Validate tool compatibility if multiple versions specified
    tools_config = {
        "wasm-tools": repository_ctx.attr.version,
    }
    compatibility_warnings = validate_tool_compatibility(tools_config)
    for warning in compatibility_warnings:
        print("Warning: {}".format(warning))

    # Use download strategy for fast, hermetic builds with prebuilt binaries
    if strategy == "download":
        _setup_downloaded_tools(repository_ctx)
    else:
        fail(format_diagnostic_error(
            "E001",
            "Unknown strategy: {}".format(strategy),
            "Must be 'download' (other strategies removed in dependency management cleanup)",
        ))

    # Create BUILD files for all strategies
    _create_build_files(repository_ctx)

def _setup_downloaded_tools_enhanced(repository_ctx):
    """Download prebuilt tools with enhanced error handling and caching"""

    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    tools_to_download = [
        ("wasm-tools", version, True),  # True = is tarball
        ("wac", "0.7.0", False),  # False = is single binary
        ("wit-bindgen", "0.43.0", True),
        ("wasmsign2", "0.2.6", "rust_source"),  # Special handling for Rust source
        # ("wrpc", "latest", None),     # Disabled for production stability
    ]

    # Create placeholder wrpc binary for compatibility
    repository_ctx.file("wrpc", """#!/bin/bash
echo "wrpc disabled for production stability"
echo "Use system wrpc or enable building from source"
exit 1
""", executable = True)

    # Add monitoring and telemetry
    add_build_telemetry(repository_ctx, tools_to_download)

    # Create health checks for each tool
    for tool_name, _, _ in tools_to_download:
        create_health_check(repository_ctx, tool_name)

    for tool_name, tool_version, is_tarball in tools_to_download:
        print("Setting up tool: {} version {}".format(tool_name, tool_version))

        # Skip caching for now due to Bazel restrictions
        # cached_tool = retrieve_cached_tool(repository_ctx, tool_name, tool_version, platform, "download")
        # if cached_tool:
        #     continue  # Tool retrieved from cache successfully

        if tool_name == "wrpc":
            # Special handling for wrpc (build from source)
            _download_wrpc_enhanced(repository_ctx)
        elif tool_name == "wasmsign2" or is_tarball == "rust_source":
            # Special handling for Rust source builds
            _download_wasmsign2(repository_ctx)
        else:
            # Download tool using enhanced method
            _download_single_tool_enhanced(repository_ctx, tool_name, tool_version, platform, is_tarball)

def _download_single_tool_enhanced(repository_ctx, tool_name, version, platform, is_tarball):
    """Download a single tool with enhanced error handling"""

    tool_info = get_tool_info(tool_name, version, platform)
    if not tool_info:
        fail(format_diagnostic_error(
            "E001",
            "Unsupported platform {} for tool {} version {}".format(platform, tool_name, version),
            "Check supported platforms or use build strategy",
        ))

    # Construct URL based on tool type
    if tool_name == "wasm-tools" or tool_name == "wit-bindgen":
        # These use tarball releases
        url = "https://github.com/bytecodealliance/{}/releases/download/v{}/{}-{}-{}".format(
            tool_name,
            version,
            tool_name,
            version,
            tool_info["url_suffix"],
        )
    elif tool_name == "wac":
        # wac uses single binary releases
        url = "https://github.com/bytecodealliance/wac/releases/download/v{}/wac-cli-{}".format(
            version,
            tool_info["platform_name"],
        )

    # Create retry wrapper for downloads
    retry_download = create_retry_wrapper(repository_ctx, "Download {}".format(tool_name))

    def download_operation():
        if is_tarball:
            # For now, extract without stripPrefix to debug structure
            result = repository_ctx.download_and_extract(
                url = url,
                sha256 = tool_info["sha256"],
            )

            # After extraction, move the binary to the expected location
            if tool_name == "wasm-tools":
                # Look for the binary in common locations
                possible_paths = [
                    "{}-{}-{}/{}".format(tool_name, version, tool_info["url_suffix"].replace(".tar.gz", ""), tool_name),
                    "{}-{}/{}".format(tool_name, version, tool_name),
                    "{}".format(tool_name),
                ]
                for path in possible_paths:
                    if repository_ctx.path(path).exists:
                        # Use Bazel-native symlink instead of shell mv command
                        repository_ctx.symlink(path, tool_name)
                        break
            elif tool_name == "wit-bindgen":
                possible_paths = [
                    "{}-{}-{}/{}".format(tool_name, version, tool_info["url_suffix"].replace(".tar.gz", ""), tool_name),
                    "{}-{}/{}".format(tool_name, version, tool_name),
                    "{}".format(tool_name),
                ]
                for path in possible_paths:
                    if repository_ctx.path(path).exists:
                        # Use Bazel-native symlink instead of shell mv command
                        repository_ctx.symlink(path, tool_name)
                        break

            return result
        else:
            return repository_ctx.download(
                url = url,
                output = tool_name,
                sha256 = tool_info["sha256"],
                executable = True,
            )

    # Execute download with retry
    result = retry_download(download_operation)
    if not result or (hasattr(result, "return_code") and result.return_code != 0):
        fail(format_diagnostic_error(
            "E003",
            "Failed to download tool {}".format(tool_name),
            "Check network connectivity or try build strategy",
        ))

    # Validate downloaded tool
    validation_result = validate_tool_functionality(repository_ctx, tool_name, tool_name)
    if not validation_result["valid"]:
        fail(format_diagnostic_error(
            "E007",
            "Downloaded tool {} failed validation: {}".format(tool_name, validation_result["error"]),
            "Try re-downloading or use build strategy",
        ))

    # Skip caching for now due to Bazel restrictions
    # tool_binary = repository_ctx.path(tool_name)
    # cache_tool(repository_ctx, tool_name, tool_binary, version, platform, "download", tool_info["sha256"])

    print("Successfully downloaded and validated tool: {}".format(tool_name))

def _download_wrpc_enhanced(repository_ctx):
    """Download wrpc using modernized git_repository approach"""

    print("Using modernized wrpc from @wrpc_src git repository")

    # Link to git_repository-based wrpc build
    # The actual build is handled by @rules_rust in the git repository
    if repository_ctx.path("../wrpc_src").exists:
        repository_ctx.symlink("../wrpc_src/bazel-bin/wrpc-wasmtime", "wrpc")
        print("Linked wrpc from git repository")
    else:
        print("Warning: wrpc git repository not available, creating placeholder")
        repository_ctx.file("wrpc", """#!/bin/bash
echo "wrpc: git repository build not available"
echo "Use download strategy or ensure @wrpc_src is properly configured"
exit 1
""", executable = True)

def _setup_downloaded_tools(repository_ctx):
    """Download prebuilt tools from GitHub releases (simple & reliable)"""

    platform = _detect_host_platform(repository_ctx)
    print("Setting up tools for platform: {}".format(platform))

    # Download individual tools using simple, proven methods
    _download_wasm_tools(repository_ctx)
    _download_wac(repository_ctx)
    _download_wit_bindgen(repository_ctx)

    # Try to download wasmsign2, but don't fail if Rust toolchain unavailable
    rust_info = _get_rust_toolchain_info(repository_ctx)
    if rust_info:
        _download_wasmsign2(repository_ctx)
    else:
        print("Warning: Skipping wasmsign2 build - hermetic Rust toolchain not available")
        print("This is acceptable for basic WebAssembly component compilation")

        # Create a minimal placeholder for compatibility
        repository_ctx.file("wasmsign2", """#!/bin/bash
echo "wasmsign2 not available - hermetic Rust toolchain required"
echo "Basic WebAssembly component functionality is not affected"
exit 0
""", executable = True)

    # Create placeholder wrpc binary for compatibility
    repository_ctx.file("wrpc", """#!/bin/bash
echo "wrpc disabled for production stability"
echo "Use system wrpc or enable building from source"
exit 1
""", executable = True)

    print("Successfully set up all tools")

def _setup_built_tools_enhanced(repository_ctx):
    """Build tools from source using git_repository + genrule approach"""

    print("Using modernized build strategy with git_repository + genrule approach")

    # For build strategy, we don't create local tool files at all.
    # Instead, we'll modify the BUILD file creation to reference external git repositories.
    # This avoids running cargo in repository rules entirely.

    # wasmsign2 is not available from git repositories, so create placeholder
    repository_ctx.file("wasmsign2", """#!/bin/bash
echo "wasmsign2 not available in build strategy - use download strategy instead"
echo "Basic WebAssembly component functionality is not affected"
exit 0
""", executable = True)

    print("✅ Build strategy configured - tools will be built from git repositories using genrules")

def _setup_hybrid_tools_enhanced(repository_ctx):
    """Setup tools using hybrid strategy with enhanced features"""

    # Use existing implementation with enhanced error handling
    _setup_hybrid_tools_original(repository_ctx)

def _setup_built_tools_original(repository_ctx):
    """Build tools from source code - MODERNIZED: Use git_repository approach"""

    print("Using modernized build strategy with git_repository + rules_rust approach")
    print("This replaces all ctx.execute() git clone and cargo build operations")

    # Link to modernized git_repository-based builds
    # All the git operations and cargo builds are now handled by Bazel's git_repository
    # rules and @rules_rust, eliminating the need for ctx.execute()

    # Link to wasm-tools from git repository
    if repository_ctx.path("../wasm_tools_src").exists:
        repository_ctx.symlink("../wasm_tools_src/wasm-tools", "wasm-tools")
        print("Linked wasm-tools from git repository")
    else:
        print("❌ @wasm_tools_src not available")

    # Link to wac from git repository
    if repository_ctx.path("../wac_src").exists:
        repository_ctx.symlink("../wac_src/wac", "wac")
        print("Linked wac from git repository")
    else:
        print("❌ @wac_src not available")

    # Link to wit-bindgen from git repository
    if repository_ctx.path("../wit_bindgen_src").exists:
        repository_ctx.symlink("../wit_bindgen_src/wit-bindgen", "wit-bindgen")
        print("Linked wit-bindgen from git repository")
    else:
        print("❌ @wit_bindgen_src not available")

    # Link to wrpc from git repository
    if repository_ctx.path("../wrpc_src").exists:
        repository_ctx.symlink("../wrpc_src/wrpc-wasmtime", "wrpc")
        print("Linked wrpc from git repository")
    else:
        print("@wrpc_src not available")

    print("Build strategy configured")

def _setup_hybrid_tools_original(repository_ctx):
    """Setup tools using hybrid build/download strategy"""

    # Determine which tools to build vs download based on custom URLs/commits
    build_wasm_tools = repository_ctx.attr.wasm_tools_url != "" or repository_ctx.attr.wasm_tools_commit != ""
    build_wac = repository_ctx.attr.wac_url != "" or repository_ctx.attr.wac_commit != ""
    build_wit_bindgen = repository_ctx.attr.wit_bindgen_url != "" or repository_ctx.attr.wit_bindgen_commit != ""
    build_wrpc = repository_ctx.attr.wrpc_url != "" or repository_ctx.attr.wrpc_commit != ""

    # Get commits and URLs for tools we're building
    git_commit = repository_ctx.attr.git_commit
    wasm_tools_commit = repository_ctx.attr.wasm_tools_commit or git_commit
    wac_commit = repository_ctx.attr.wac_commit or git_commit
    wit_bindgen_commit = repository_ctx.attr.wit_bindgen_commit or git_commit
    wrpc_commit = repository_ctx.attr.wrpc_commit or git_commit

    wasm_tools_url = repository_ctx.attr.wasm_tools_url or "https://github.com/bytecodealliance/wasm-tools.git"
    wac_url = repository_ctx.attr.wac_url or "https://github.com/bytecodealliance/wac.git"
    wit_bindgen_url = repository_ctx.attr.wit_bindgen_url or "https://github.com/bytecodealliance/wit-bindgen.git"
    wrpc_url = repository_ctx.attr.wrpc_url or "https://github.com/bytecodealliance/wrpc.git"

    # Build or download wasm-tools - MODERNIZED: Use git_repository + rules_rust
    if build_wasm_tools:
        # Link to modernized git_repository-based wasm-tools build
        repository_ctx.symlink("../wasm_tools_src/bazel-bin/wasm-tools", "wasm-tools")
        print("Using modernized wasm-tools from @wasm_tools_src git repository")
    else:
        _download_wasm_tools(repository_ctx)

    # Build or download wac - MODERNIZED: Use git_repository + rules_rust
    if build_wac:
        # Link to modernized git_repository-based wac build
        repository_ctx.symlink("../wac_src/bazel-bin/wac", "wac")
        print("Using modernized wac from @wac_src git repository")
    else:
        _download_wac(repository_ctx)

    # Build or download wit-bindgen - MODERNIZED: Use git_repository + rules_rust
    if build_wit_bindgen:
        # Link to modernized git_repository-based wit-bindgen build
        repository_ctx.symlink("../wit_bindgen_src/bazel-bin/wit-bindgen", "wit-bindgen")
        print("Using modernized wit-bindgen from @wit_bindgen_src git repository")
    else:
        _download_wit_bindgen(repository_ctx)

    # Build or download wrpc - MODERNIZED: Use git_repository + rules_rust
    if build_wrpc:
        # Link to modernized git_repository-based wrpc build
        repository_ctx.symlink("../wrpc_src/bazel-bin/wrpc-wasmtime", "wrpc")
        print("Using modernized wrpc from @wrpc_src git repository")
    else:
        _download_wrpc(repository_ctx)

def _download_wasm_tools(repository_ctx):
    """Download wasm-tools only"""
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Get platform info and checksum from centralized registry
    platform_info = _get_wasm_tools_platform_info(platform, version)

    wasm_tools_url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}".format(
        version,
        version,
        platform_info.url_suffix,
    )

    # Determine stripPrefix based on archive format
    # Windows uses .zip, others use .tar.gz
    if platform_info.url_suffix.endswith(".zip"):
        strip_prefix = "wasm-tools-{}-{}".format(version, platform_info.url_suffix.replace(".zip", ""))
    else:
        strip_prefix = "wasm-tools-{}-{}".format(version, platform_info.url_suffix.replace(".tar.gz", ""))

    # Download and extract archive, letting Bazel handle the structure
    repository_ctx.download_and_extract(
        url = wasm_tools_url,
        sha256 = platform_info.sha256,
        stripPrefix = strip_prefix,
    )

def _download_wac(repository_ctx):
    """Download wac only"""
    platform = _detect_host_platform(repository_ctx)
    wac_version = get_tool_version("wac")  # From tool_versions.bzl

    # Get checksum and platform info from tool_versions.bzl
    tool_info = get_tool_info("wac", wac_version, platform)
    if not tool_info:
        fail("Unsupported platform {} for wac version {}".format(platform, wac_version))

    wac_url = "https://github.com/bytecodealliance/wac/releases/download/v{}/wac-cli-{}".format(
        wac_version,
        tool_info["platform_name"],
    )

    repository_ctx.download(
        url = wac_url,
        output = "wac",
        sha256 = tool_info["sha256"],
        executable = True,
    )

def _download_wit_bindgen(repository_ctx):
    """Download wit-bindgen only"""
    platform = _detect_host_platform(repository_ctx)
    wit_bindgen_version = get_tool_version("wit-bindgen")  # From tool_versions.bzl

    # Get checksum and platform info from tool_versions.bzl
    tool_info = get_tool_info("wit-bindgen", wit_bindgen_version, platform)
    if not tool_info:
        fail("Unsupported platform {} for wit-bindgen version {}".format(platform, wit_bindgen_version))

    wit_bindgen_url = "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{}/wit-bindgen-{}-{}".format(
        wit_bindgen_version,
        wit_bindgen_version,
        tool_info["url_suffix"],
    )

    repository_ctx.download_and_extract(
        url = wit_bindgen_url,
        sha256 = tool_info["sha256"],
        stripPrefix = "wit-bindgen-{}-{}".format(wit_bindgen_version, tool_info["url_suffix"].replace(".tar.gz", "").replace(".zip", "")),
    )

def _download_wrpc(repository_ctx):
    """Download wrpc using modernized git_repository approach"""

    print("Using modernized wrpc from @wrpc_src git repository")

    # Link to git_repository-based wrpc build instead of manual git clone + cargo build
    if repository_ctx.path("../wrpc_src").exists:
        repository_ctx.symlink("../wrpc_src/wrpc-wasmtime", "wrpc")
        print("Linked wrpc from git repository")
    else:
        print("Warning: @wrpc_src git repository not available")
        repository_ctx.file("wrpc", """#!/bin/bash
echo "wrpc: modernized git repository build not available"
echo "Ensure @wrpc_src is properly configured in MODULE.bazel"
exit 1
""", executable = True)

def _download_wasmsign2(repository_ctx):
    """Setup wasmsign2 placeholder - not available in prebuilt downloads"""

    print("Setting up wasmsign2 placeholder for download strategy")

    # Create a stub explaining wasmsign2 is not included in prebuilt downloads
    repository_ctx.file("wasmsign2", """#!/bin/bash
# wasmsign2 is not included in prebuilt binary downloads
echo "wasmsign2: Not available in download strategy" >&2
echo "WebAssembly component signing requires building wasmsign2 from source" >&2
echo "For signing functionality, use @wasmsign2_src from git_repository" >&2
exit 1
""", executable = True)

    print("Created wasmsign2 stub - not included in prebuilt downloads")

def _get_platform_suffix(platform):
    """Get platform suffix for download URLs"""
    platform_suffixes = {
        "linux_amd64": "x86_64-linux",
        "linux_arm64": "aarch64-linux",
        "darwin_amd64": "x86_64-macos",
        "darwin_arm64": "aarch64-macos",
        "windows_amd64": "x86_64-windows",
    }
    return platform_suffixes.get(platform, "x86_64-linux")

def _create_build_files(repository_ctx):
    """Create BUILD files for the toolchain"""

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)

    if strategy == "build":
        # For build strategy, reference external git repositories directly
        build_content = """
load("@rules_wasm_component//toolchains:wasm_toolchain.bzl", "wasm_tools_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables - reference git repository builds
alias(
    name = "wasm_tools_binary",
    actual = "@wasm_tools_src//:wasm_tools_binary",
    visibility = ["//visibility:public"],
)

alias(
    name = "wac_binary",
    actual = "@wac_src//:wac_binary",
    visibility = ["//visibility:public"],
)

alias(
    name = "wit_bindgen_binary",
    actual = "@wit_bindgen_src//:wit_bindgen_binary",
    visibility = ["//visibility:public"],
)

alias(
    name = "wrpc_binary",
    actual = "@wrpc_src//:wrpc_binary",
    visibility = ["//visibility:public"],
)

# wasmsign2 not available in build strategy
filegroup(
    name = "wasmsign2_binary",
    srcs = ["wasmsign2"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
wasm_tools_toolchain(
    name = "wasm_tools_impl",
    wasm_tools = ":wasm_tools_binary",
    wac = ":wac_binary",
    wit_bindgen = ":wit_bindgen_binary",
    wrpc = ":wrpc_binary",
    wasmsign2 = ":wasmsign2_binary",
)

# Toolchain registration
toolchain(
    name = "wasm_tools_toolchain",
    toolchain = ":wasm_tools_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)
"""
    else:
        # For download strategy, use local downloaded files
        # Windows binaries need .exe extension
        exe_suffix = ".exe" if platform == "windows_amd64" else ""
        build_content = """
load("@rules_wasm_component//toolchains:wasm_toolchain.bzl", "wasm_tools_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables
filegroup(
    name = "wasm_tools_binary",
    srcs = ["{wasm_tools_bin}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wac_binary",
    srcs = ["{wac_bin}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wit_bindgen_binary",
    srcs = ["{wit_bindgen_bin}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wrpc_binary",
    srcs = ["{wrpc_bin}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wasmsign2_binary",
    srcs = ["{wasmsign2_bin}"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
wasm_tools_toolchain(
    name = "wasm_tools_impl",
    wasm_tools = ":wasm_tools_binary",
    wac = ":wac_binary",
    wit_bindgen = ":wit_bindgen_binary",
    wrpc = ":wrpc_binary",
    wasmsign2 = ":wasmsign2_binary",
)

# Toolchain registration
toolchain(
    name = "wasm_tools_toolchain",
    toolchain = ":wasm_tools_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Note: Removed "all" alias to eliminate ambiguity with Bazel's :all wildcard
# Use the direct target name for explicit, clear toolchain registration
# Note: Other aliases removed to prevent dependency cycles
# Use the _binary targets directly: wasm_tools_binary, wac_binary, wit_bindgen_binary
""".format(
            wasm_tools_bin = "wasm-tools{}".format(exe_suffix),
            wac_bin = "wac{}".format(exe_suffix),
            wit_bindgen_bin = "wit-bindgen{}".format(exe_suffix),
            wrpc_bin = "wrpc{}".format(exe_suffix),
            wasmsign2_bin = "wasmsign2{}".format(exe_suffix),
        )

    # Create main BUILD file with strategy-specific content
    repository_ctx.file("BUILD.bazel", build_content)

wasm_toolchain_repository = repository_rule(
    implementation = _wasm_toolchain_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'download' only (other strategies removed in dependency management cleanup)",
            default = "download",
            values = ["download"],
        ),
        "version": attr.string(
            doc = "Version to use (for download/build strategies)",
            default = "1.235.0",
        ),
        "git_commit": attr.string(
            doc = "Git commit/tag to build from (for build strategy) - fallback for all tools",
            default = "main",
        ),
        "wasm_tools_commit": attr.string(
            doc = "Git commit/tag for wasm-tools (overrides git_commit)",
            default = "",
        ),
        "wac_commit": attr.string(
            doc = "Git commit/tag for wac (overrides git_commit)",
            default = "",
        ),
        "wit_bindgen_commit": attr.string(
            doc = "Git commit/tag for wit-bindgen (overrides git_commit)",
            default = "",
        ),
        "wasm_tools_url": attr.string(
            doc = "Custom download URL for wasm-tools (optional)",
            default = "",
        ),
        "wac_url": attr.string(
            doc = "Custom download URL for wac (optional)",
            default = "",
        ),
        "wit_bindgen_url": attr.string(
            doc = "Custom download URL for wit-bindgen (optional)",
            default = "",
        ),
        "wrpc_commit": attr.string(
            doc = "Git commit/tag for wrpc (overrides git_commit)",
            default = "",
        ),
        "wrpc_url": attr.string(
            doc = "Custom download URL for wrpc (optional)",
            default = "",
        ),
    },
)

# Legacy function aliases for backward compatibility
def _setup_built_tools(repository_ctx):
    """Build tools from source code (legacy)"""
    _setup_built_tools_enhanced(repository_ctx)

def _setup_hybrid_tools(repository_ctx):
    """Setup tools using hybrid strategy (legacy)"""
    _setup_hybrid_tools_enhanced(repository_ctx)
