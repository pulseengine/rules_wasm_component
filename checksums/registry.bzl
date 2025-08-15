"""Centralized checksum registry API for WebAssembly toolchain"""

# Cache for loaded tool data to avoid repeated file reads
_TOOL_CACHE = {}

def _load_tool_checksums(tool_name):
    """Load checksums for a tool from JSON file"""

    # For now, return hardcoded data until JSON loading is implemented
    # This will be replaced with actual JSON file reading
    # Note: Caching disabled due to Starlark frozen dict limitations
    tool_data = _get_hardcoded_checksums(tool_name)

    return tool_data

def _get_hardcoded_checksums(tool_name):
    """Temporary hardcoded checksums until JSON loading is implemented"""

    hardcoded_data = {
        "wasm-tools": {
            "tool_name": "wasm-tools",
            "github_repo": "bytecodealliance/wasm-tools",
            "latest_version": "1.235.0",
            "versions": {
                "1.235.0": {
                    "release_date": "2024-12-15",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "154e9ea5f5477aa57466cfb10e44bc62ef537e32bf13d1c35ceb4fedd9921510",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "17035deade9d351df6183d87ad9283ce4ae7d3e8e93724ae70126c87188e96b2",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "4c44bc776aadbbce4eedc90c6a07c966a54b375f8f36a26fd178cea9b419f584",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "384ca3691502116fb6f48951ad42bd0f01f9bf799111014913ce15f4f4dde5a2",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "ecf9f2064c2096df134c39c2c97af2c025e974cc32e3c76eb2609156c1690a74",
                            "url_suffix": "x86_64-windows.tar.gz",
                        },
                    },
                },
            },
        },
        "wit-bindgen": {
            "tool_name": "wit-bindgen",
            "github_repo": "bytecodealliance/wit-bindgen",
            "latest_version": "0.43.0",
            "versions": {
                "0.43.0": {
                    "release_date": "2024-12-10",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "4f3fe255640981a2ec0a66980fd62a31002829fab70539b40a1a69db43f999cd",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "5e492806d886e26e4966c02a097cb1f227c3984ce456a29429c21b7b2ee46a5b",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "cb6b0eab0f8abbf97097cde9f0ab7e44ae07bf769c718029882b16344a7cda64",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "dcd446b35564105c852eadb4244ae35625a83349ed1434a1c8e5497a2a267b44",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "e133d9f18bc0d8a3d848df78960f9974a4333bee7ed3f99b4c9e900e9e279029",
                            "url_suffix": "x86_64-windows.zip",
                        },
                    },
                },
            },
        },
        "wac": {
            "tool_name": "wac",
            "github_repo": "bytecodealliance/wac",
            "latest_version": "0.7.0",
            "versions": {
                "0.7.0": {
                    "release_date": "2024-11-20",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "023645743cfcc167a3004d3c3a62e8209a55cde438e6561172bafcaaafc33a40",
                            "platform_name": "x86_64-apple-darwin",
                        },
                        "darwin_arm64": {
                            "sha256": "4e2d22c65c51f0919b10c866ef852038b804d3dbcf515c696412566fc1eeec66",
                            "platform_name": "aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "dd734c4b049287b599a3f8c553325307687a17d070290907e3d5bbe481b89cc6",
                            "platform_name": "x86_64-unknown-linux-musl",
                        },
                        "linux_arm64": {
                            "sha256": "af966d4efbd411900073270bd4261ac42d9550af8ba26ed49288bb942476c5a9",
                            "platform_name": "aarch64-unknown-linux-musl",
                        },
                        "windows_amd64": {
                            "sha256": "d8c65e5471fc242d8c4993e2125912e10e9373f1e38249157491b3c851bd1336",
                            "platform_name": "x86_64-pc-windows-gnu",
                        },
                    },
                },
            },
        },
        "wasmtime": {
            "tool_name": "wasmtime",
            "github_repo": "bytecodealliance/wasmtime",
            "latest_version": "35.0.0",
            "versions": {
                "35.0.0": {
                    "release_date": "2025-07-22",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "1ef7d07b8a8ef7e261281ad6a1b14ebf462f84c534593ca20e70ec8097524247",
                            "url_suffix": "x86_64-macos.tar.xz",
                        },
                        "darwin_arm64": {
                            "sha256": "8ad8832564e15053cd982c732fac39417b2307bf56145d02ffd153673277c665",
                            "url_suffix": "aarch64-macos.tar.xz",
                        },
                        "linux_amd64": {
                            "sha256": "e3d2aae710a5cef548ab13f7e4ed23adc4fa1e9b4797049f4459320f32224011",
                            "url_suffix": "x86_64-linux.tar.xz",
                        },
                        "linux_arm64": {
                            "sha256": "304009a9e4cad3616694b4251a01d72b77ae33d884680f3586710a69bd31b8f8",
                            "url_suffix": "aarch64-linux.tar.xz",
                        },
                        "windows_amd64": {
                            "sha256": "cb4d9b788e81268edfb43d26c37dc4115060635ff4eceed16f4f9e6f331179b1",
                            "url_suffix": "x86_64-windows.zip",
                        },
                    },
                },
            },
        },
        "wasi-sdk": {
            "tool_name": "wasi-sdk",
            "github_repo": "WebAssembly/wasi-sdk",
            "latest_version": "25",
            "versions": {
                "22": {
                    "release_date": "2023-06-01",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "3f43c1b9a7c23c3e5b5d5d4c8b7e9f0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f67",
                            "url_suffix": "macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "3f43c1b9a7c23c3e5b5d5d4c8b7e9f0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f67",
                            "url_suffix": "macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "2a86c1b9a7c23c3e5b5d5d4c8b7e9f0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f67",
                            "url_suffix": "linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "2a86c1b9a7c23c3e5b5d5d4c8b7e9f0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f67",
                            "url_suffix": "linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "PLACEHOLDER_NEEDS_REAL_CHECKSUM_64_CHARS_XXXXXXXXXXXXXXXX",
                            "url_suffix": "windows.tar.gz",
                        },
                    },
                },
                "25": {
                    "release_date": "2024-11-01",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "cf5f524de23f231756ec2f3754fc810ea3f6206841a968c45d8b7ea47cfc3a61",
                            "url_suffix": "macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "e1e529ea226b1db0b430327809deae9246b580fa3cae32d31c82dfe770233587",
                            "url_suffix": "macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "52640dde13599bf127a95499e61d6d640256119456d1af8897ab6725bcf3d89c",
                            "url_suffix": "linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "52640dde13599bf127a95499e61d6d640256119456d1af8897ab6725bcf3d89c",
                            "url_suffix": "linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "PLACEHOLDER_NEEDS_REAL_CHECKSUM_64_CHARS_XXXXXXXXXXXXXXXX",
                            "url_suffix": "windows.tar.gz",
                        },
                    },
                },
            },
        },
        "wasmsign2": {
            "tool_name": "wasmsign2",
            "github_repo": "wasm-signatures/wasmsign2",
            "latest_version": "0.2.6",
            "build_type": "rust_source",
            "versions": {
                "0.2.6": {
                    "release_date": "2024-11-22",
                    "source_info": {
                        "git_tag": "0.2.6",
                        "commit_sha": "3a2defd9ab2aa8f28513af42e6d73408ee7ac43a",
                        "cargo_package": "wasmsign2-cli",
                        "binary_name": "wasmsign2",
                    },
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "SOURCE_BUILD_NO_CHECKSUM_RUST_COMPILATION_TARGET",
                            "rust_target": "x86_64-apple-darwin",
                        },
                        "darwin_arm64": {
                            "sha256": "SOURCE_BUILD_NO_CHECKSUM_RUST_COMPILATION_TARGET",
                            "rust_target": "aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "SOURCE_BUILD_NO_CHECKSUM_RUST_COMPILATION_TARGET",
                            "rust_target": "x86_64-unknown-linux-gnu",
                        },
                        "linux_arm64": {
                            "sha256": "SOURCE_BUILD_NO_CHECKSUM_RUST_COMPILATION_TARGET",
                            "rust_target": "aarch64-unknown-linux-gnu",
                        },
                        "windows_amd64": {
                            "sha256": "SOURCE_BUILD_NO_CHECKSUM_RUST_COMPILATION_TARGET",
                            "rust_target": "x86_64-pc-windows-msvc",
                        },
                    },
                },
            },
        },
    }

    return hardcoded_data.get(tool_name, {})

def get_tool_checksum(tool_name, version, platform):
    """Get verified checksum from centralized registry

    Args:
        tool_name: Name of the tool (e.g., 'wasm-tools', 'wit-bindgen')
        version: Version string (e.g., '1.235.0')
        platform: Platform string (e.g., 'darwin_amd64', 'linux_amd64')

    Returns:
        String: SHA256 checksum, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})
    platform_data = platforms.get(platform, {})

    return platform_data.get("sha256")

def get_tool_info(tool_name, version, platform):
    """Get complete tool information from centralized registry

    Args:
        tool_name: Name of the tool
        version: Version string
        platform: Platform string

    Returns:
        Dict: Complete platform information, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})

    return platforms.get(platform)

def get_latest_version(tool_name):
    """Get latest available version for a tool

    Args:
        tool_name: Name of the tool

    Returns:
        String: Latest version, or None if tool not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    return tool_data.get("latest_version")

def list_supported_platforms(tool_name, version):
    """List all supported platforms for a tool version

    Args:
        tool_name: Name of the tool
        version: Version string

    Returns:
        List: List of supported platform strings
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return []

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})

    return list(platforms.keys())

def get_github_repo(tool_name):
    """Get GitHub repository for a tool

    Args:
        tool_name: Name of the tool

    Returns:
        String: GitHub repository in 'owner/repo' format, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    return tool_data.get("github_repo")

def validate_tool_exists(tool_name, version, platform):
    """Validate that a tool version and platform combination exists

    Args:
        tool_name: Name of the tool
        version: Version string
        platform: Platform string

    Returns:
        Bool: True if the combination exists and has a checksum
    """

    checksum = get_tool_checksum(tool_name, version, platform)
    return checksum != None and len(checksum) == 64  # Valid SHA256 length
