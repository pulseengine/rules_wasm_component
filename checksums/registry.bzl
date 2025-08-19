"""Centralized checksum registry API for WebAssembly toolchain

This module provides a unified API for accessing tool checksums. Checksum data is
embedded in this file and kept synchronized with checksums/tools/*.json files, which
serve as the canonical source for checksum updater tools and external documentation.

The embedded approach is used because Bazel rules don't have built-in JSON parsing
capabilities, making direct JSON loading impractical in the build system.
"""

def _load_tool_checksums(tool_name):
    """Load checksums for a tool from embedded registry data

    Args:
        tool_name: Name of the tool (e.g., 'wasm-tools', 'wit-bindgen')

    Returns:
        Dict: Tool data from embedded registry, or empty dict if not found

    Note:
        This function uses embedded data rather than JSON file loading because
        Bazel rules don't have built-in JSON parsing capabilities. The embedded
        data is kept synchronized with checksums/tools/*.json files, which serve
        as the canonical source for checksum updater tools and documentation.
    """

    tool_data = _get_fallback_checksums(tool_name)
    return tool_data

def _get_fallback_checksums(tool_name):
    """Fallback checksums sourced from JSON files

    This data is synchronized with checksums/tools/*.json files.
    Eventually this will be replaced with direct JSON loading.
    """

    fallback_data = {
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
                "1.236.0": {
                    "release_date": "2025-07-28",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "d9356a9de047598d6c2b8ff4a5318c9305485152430e85ceec78052a9bd08828",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "d3094124e18f17864bd0e0de93f1938a466aca374c180962b2ba670a5ec9c8cf",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "a4fe8101d98f4efeb4854fde05d7c6a36a9a61e8249d4c72afcda4a4944723fb",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "c11b4d02bd730a8c3e60f4066602ce4264a752013d6c9ec58d70b7f276c3b794",
                            "url_suffix": "aarch64-linux.tar.gz",
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
                    "release_date": "2025-06-24",
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
        "wkg": {
            "tool_name": "wkg",
            "github_repo": "bytecodealliance/wasm-pkg-tools",
            "latest_version": "0.11.0",
            "versions": {
                "0.11.0": {
                    "release_date": "2025-06-19",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "f1b6f71ce8b45e4fae0139f4676bc3efb48a89c320b5b2df1a1fd349963c5f82",
                            "binary_name": "wkg-x86_64-apple-darwin",
                        },
                        "darwin_arm64": {
                            "sha256": "e90a1092b1d1392052f93684afbd28a18fdf5f98d7175f565e49389e913d7cea",
                            "binary_name": "wkg-aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "e3bec9add5a739e99ee18503ace07d474ce185d3b552763785889b565cdcf9f2",
                            "binary_name": "wkg-x86_64-unknown-linux-gnu",
                        },
                        "linux_arm64": {
                            "sha256": "159ffe5d321217bf0f449f2d4bde9fe82fee2f9387b55615f3e4338eb0015e96",
                            "binary_name": "wkg-aarch64-unknown-linux-gnu",
                        },
                        "windows_amd64": {
                            "sha256": "ac7b06b91ea80973432d97c4facd78e84187e4d65b42613374a78c4c584f773c",
                            "binary_name": "wkg-x86_64-pc-windows-gnu",
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
            "latest_version": "27",
            "versions": {
                "27": {
                    "release_date": "2025-07-28",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "163dfd47f989b1a682744c1ae1f0e09a83ff5c4bbac9dcd8546909ab54cda5a1",
                            "url_suffix": "macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "055c3dc2766772c38e71a05d353e35c322c7b2c6458a36a26a836f9808a550f8",
                            "url_suffix": "macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "b7d4d944c88503e4f21d84af07ac293e3440b1b6210bfd7fe78e0afd92c23bc2",
                            "url_suffix": "linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "4cf4c553c4640e63e780442146f87d83fdff5737f988c06a6e3b2f0228e37665",
                            "url_suffix": "linux.tar.gz",
                        },
                    },
                },
                "26": {
                    "release_date": "2025-07-28",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "9853b66701d017cb17e53beb2e540e522bdded772fd1661ce29a88eb8b333902",
                            "url_suffix": "macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "f6c76a183cf7fce9fc8af95b10f851a679f8ea6dae0354c5f84b52157a3398e1",
                            "url_suffix": "macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "37cddd06e354b0354db40e42a011752b0d5b77075af4bc5a2e0999aab908484e",
                            "url_suffix": "linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "7ba6e76f2b1bb7b85429ebe96a4d867923f14cbd77a55f31fca6e02b26fe0754",
                            "url_suffix": "linux.tar.gz",
                        },
                    },
                },
                "25": {
                    "release_date": "2024-11-01",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "55e3ff3fee1a15678a16eeccba0129276c9f6be481bc9c283e7f9f65bf055c11",
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
                            "sha256": "47fccad8b2498f2239e05e1115c3ffc652bf37e7de2f88fb64b2d663c976ce2d",
                            "url_suffix": "arm64-linux.tar.gz",
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
        "nodejs": {
            "tool_name": "nodejs",
            "github_repo": "nodejs/node",
            "latest_version": "18.19.0",
            "build_type": "download",
            "versions": {
                "18.19.0": {
                    "release_date": "2024-01-09",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "0a749fcdf5d6bf46e1c17b3ea01e050b4d1ec3f3073b14aa745527b45a759c74",
                            "url_suffix": "darwin-x64.tar.gz",
                            "binary_path": "node-v{}-darwin-x64/bin/node",
                            "npm_path": "node-v{}-darwin-x64/bin/npm",
                        },
                        "darwin_arm64": {
                            "sha256": "8907c42a968765b77730fb319458d63ec4ed009265f8012097c3a052407aa99b",
                            "url_suffix": "darwin-arm64.tar.gz",
                            "binary_path": "node-v{}-darwin-arm64/bin/node",
                            "npm_path": "node-v{}-darwin-arm64/bin/npm",
                        },
                        "linux_amd64": {
                            "sha256": "61632bb78ee828d6e8f42adc0bc2238a6b8200007093988d3927176a372281e8",
                            "url_suffix": "linux-x64.tar.xz",
                            "binary_path": "node-v{}-linux-x64/bin/node",
                            "npm_path": "node-v{}-linux-x64/bin/npm",
                        },
                        "linux_arm64": {
                            "sha256": "cf94ab72e45b855257545fec1c017bdf30a9e23611561382eaf64576b999e72d",
                            "url_suffix": "linux-arm64.tar.xz",
                            "binary_path": "node-v{}-linux-arm64/bin/node",
                            "npm_path": "node-v{}-linux-arm64/bin/npm",
                        },
                        "windows_amd64": {
                            "sha256": "5311913d45e1fcc3643c58d1e3926eb85437b180f025fe5857413c9f02403645",
                            "url_suffix": "win-x64.zip",
                            "binary_path": "node-v{}-win-x64/node.exe",
                            "npm_path": "node-v{}-win-x64/npm.cmd",
                        },
                    },
                },
            },
        },
        "wizer": {
            "tool_name": "wizer",
            "github_repo": "bytecodealliance/wizer",
            "latest_version": "9.0.0",
            "versions": {
                "9.0.0": {
                    "release_date": "2024-06-03",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "5d5e457abf3fd6e307dee9fe9f7423185a88d90f0c96677b9a5418c448ced52e",
                            "url_suffix": "x86_64-macos.tar.xz",
                            "strip_prefix": "wizer-v9.0.0-x86_64-macos",
                        },
                        "darwin_arm64": {
                            "sha256": "3372ee8215abc39b15a51b4aed27f8ae5a42e84261a29e7491ec82bf806bc491",
                            "url_suffix": "aarch64-macos.tar.xz",
                            "strip_prefix": "wizer-v9.0.0-aarch64-macos",
                        },
                        "linux_amd64": {
                            "sha256": "d1d85703bc40f18535e673992bef723dc3f84e074bcd1e05b57f24d5adb4f058",
                            "url_suffix": "x86_64-linux.tar.xz",
                            "strip_prefix": "wizer-v9.0.0-x86_64-linux",
                        },
                        "linux_arm64": {
                            "sha256": "f560a675d686d42c18de8bd4014a34a0e8b95dafbd696bf8d54817311ae87a4d",
                            "url_suffix": "aarch64-linux.tar.xz",
                            "strip_prefix": "wizer-v9.0.0-aarch64-linux",
                        },
                        "windows_amd64": {
                            "sha256": "d9cc5ed028ca873f40adcac513812970d34dd08cec4397ffc5a47d4acee8e782",
                            "url_suffix": "x86_64-windows.zip",
                            "strip_prefix": "wizer-v9.0.0-x86_64-windows",
                        },
                    },
                },
            },
        },
        "jco": {
            "tool_name": "jco",
            "github_repo": "bytecodealliance/jco",
            "latest_version": "1.4.0",
            "build_type": "npm_with_nodejs",
            "requires": ["nodejs"],
            "versions": {
                "1.4.0": {
                    "release_date": "2024-11-25",
                    "platforms": {
                        "universal": {
                            "npm_package": "@bytecodealliance/jco",
                            "npm_version": "1.4.0",
                            "dependencies": ["@bytecodealliance/componentize-js"],
                        },
                    },
                },
            },
        },
    }

    return fallback_data.get(tool_name, {})

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

def get_tool_metadata(tool_name):
    """Get tool metadata including GitHub repo and latest version

    Args:
        tool_name: Name of the tool

    Returns:
        Dict: Tool metadata including github_repo, latest_version, etc.
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return {}

    return {
        "tool_name": tool_data.get("tool_name"),
        "github_repo": tool_data.get("github_repo"),
        "latest_version": tool_data.get("latest_version"),
        "build_type": tool_data.get("build_type", "binary"),
    }

def list_available_tools():
    """List all available tools in the registry

    Returns:
        List: List of available tool names
    """

    # Return tools that have fallback data available
    return [
        "wasm-tools",
        "wit-bindgen",
        "wac",
        "wkg",
        "wasmtime",
        "wasi-sdk",
        "wasmsign2",
        "wizer",
        "nodejs",
        "jco",
    ]

def validate_tool_compatibility(tools_config):
    """Validate that tool versions are compatible with each other

    Args:
        tools_config: Dict mapping tool names to versions

    Returns:
        List: List of warning messages for compatibility issues
    """

    warnings = []

    # Define compatibility matrix (sourced from tool_versions.bzl)
    compatibility_matrix = {
        "1.235.0": {
            "wac": ["0.7.0"],
            "wit-bindgen": ["0.43.0"],
            "wkg": ["0.11.0"],
            "wasmsign2": ["0.2.6"],
        },
    }

    if "wasm-tools" in tools_config:
        wasm_tools_version = tools_config["wasm-tools"]
        if wasm_tools_version in compatibility_matrix:
            compat_info = compatibility_matrix[wasm_tools_version]

            for tool, version in tools_config.items():
                if tool != "wasm-tools" and tool in compat_info:
                    if version not in compat_info[tool]:
                        warnings.append(
                            "Warning: {} version {} may not be compatible with wasm-tools {}. " +
                            "Recommended versions: {}".format(
                                tool,
                                version,
                                wasm_tools_version,
                                ", ".join(compat_info[tool]),
                            ),
                        )

    return warnings

def get_recommended_versions(stability = "stable"):
    """Get recommended tool versions for a given stability level

    Args:
        stability: Stability level ("stable" or "latest")

    Returns:
        Dict: Mapping of tool names to recommended versions
    """

    # Define default versions (sourced from tool_versions.bzl)
    default_versions = {
        "stable": {
            "wasm-tools": "1.235.0",
            "wac": "0.7.0",
            "wit-bindgen": "0.43.0",
            "wkg": "0.11.0",
            "wasmsign2": "0.2.6",
            "nodejs": "18.19.0",
            "jco": "1.4.0",
        },
        "latest": {
            "wasm-tools": "1.235.0",
            "wac": "0.7.0",
            "wit-bindgen": "0.43.0",
            "wkg": "0.11.0",
            "wasmsign2": "0.2.6",
            "nodejs": "18.19.0",
            "jco": "1.4.0",
        },
    }

    if stability not in default_versions:
        fail("Unknown stability level: {}. Available: {}".format(
            stability,
            ", ".join(default_versions.keys()),
        ))

    return default_versions[stability]
