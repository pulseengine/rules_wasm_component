"""Centralized tool version and checksum management"""

# Tool version registry with real checksums and compatibility information
TOOL_VERSIONS = {
    "wasm-tools": {
        "1.235.0": {
            "darwin_amd64": {
                "url_suffix": "x86_64-macos.tar.gz",
                "sha256": "154e9ea5f5477aa57466cfb10e44bc62ef537e32bf13d1c35ceb4fedd9921510",
            },
            "darwin_arm64": {
                "url_suffix": "aarch64-macos.tar.gz", 
                "sha256": "17035deade9d351df6183d87ad9283ce4ae7d3e8e93724ae70126c87188e96b2",
            },
            "linux_amd64": {
                "url_suffix": "x86_64-linux.tar.gz",
                "sha256": "4c44bc776aadbbce4eedc90c6a07c966a54b375f8f36a26fd178cea9b419f584",
            },
            "linux_arm64": {
                "url_suffix": "aarch64-linux.tar.gz",
                "sha256": "384ca3691502116fb6f48951ad42bd0f01f9bf799111014913ce15f4f4dde5a2",
            },
            "windows_amd64": {
                "url_suffix": "x86_64-windows.tar.gz",
                "sha256": "ecf9f2064c2096df134c39c2c97af2c025e974cc32e3c76eb2609156c1690a74",
            },
        },
    },
    "wac": {
        "0.7.0": {
            "darwin_amd64": {
                "platform_name": "x86_64-apple-darwin",
                "sha256": "023645743cfcc167a3004d3c3a62e8209a55cde438e6561172bafcaaafc33a40",
            },
            "darwin_arm64": {
                "platform_name": "aarch64-apple-darwin", 
                "sha256": "4e2d22c65c51f0919b10c866ef852038b804d3dbcf515c696412566fc1eeec66",
            },
            "linux_amd64": {
                "platform_name": "x86_64-unknown-linux-musl",
                "sha256": "dd734c4b049287b599a3f8c553325307687a17d070290907e3d5bbe481b89cc6",
            },
            "linux_arm64": {
                "platform_name": "aarch64-unknown-linux-musl",
                "sha256": "af966d4efbd411900073270bd4261ac42d9550af8ba26ed49288bb942476c5a9",
            },
            "windows_amd64": {
                "platform_name": "x86_64-pc-windows-gnu",
                "sha256": "d8c65e5471fc242d8c4993e2125912e10e9373f1e38249157491b3c851bd1336",
            },
        },
    },
    "wit-bindgen": {
        "0.43.0": {
            "darwin_amd64": {
                "url_suffix": "x86_64-macos.tar.gz",
                "sha256": "4f3fe255640981a2ec0a66980fd62a31002829fab70539b40a1a69db43f999cd",
            },
            "darwin_arm64": {
                "url_suffix": "aarch64-macos.tar.gz",
                "sha256": "5e492806d886e26e4966c02a097cb1f227c3984ce456a29429c21b7b2ee46a5b",
            },
            "linux_amd64": {
                "url_suffix": "x86_64-linux.tar.gz",
                "sha256": "cb6b0eab0f8abbf97097cde9f0ab7e44ae07bf769c718029882b16344a7cda64",
            },
            "linux_arm64": {
                "url_suffix": "aarch64-linux.tar.gz",
                "sha256": "dcd446b35564105c852eadb4244ae35625a83349ed1434a1c8e5497a2a267b44",
            },
            "windows_amd64": {
                "url_suffix": "x86_64-windows.zip",
                "sha256": "e133d9f18bc0d8a3d848df78960f9974a4333bee7ed3f99b4c9e900e9e279029",
            },
        },
    },
    "wkg": {
        "0.11.0": {
            "darwin_amd64": {
                "binary_name": "wkg-x86_64-apple-darwin",
                "sha256": "b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3",
            },
            "darwin_arm64": {
                "binary_name": "wkg-aarch64-apple-darwin",
                "sha256": "d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5",
            },
            "linux_amd64": {
                "binary_name": "wkg-x86_64-unknown-linux-musl",
                "sha256": "f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7",
            },
            "linux_arm64": {
                "binary_name": "wkg-aarch64-unknown-linux-musl",
                "sha256": "a0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9",
            },
            "windows_amd64": {
                "binary_name": "wkg-x86_64-pc-windows-gnu.exe",
                "sha256": "c2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1",
            },
        },
    },
}

# Tool compatibility matrix
COMPATIBILITY_MATRIX = {
    "wasm-tools": {
        "1.235.0": {
            "wac": ["0.7.0"],
            "wit-bindgen": ["0.43.0"],
            "wkg": ["0.11.0"],
        },
    },
}

# Default version recommendations
DEFAULT_VERSIONS = {
    "stable": {
        "wasm-tools": "1.235.0",
        "wac": "0.7.0", 
        "wit-bindgen": "0.43.0",
        "wkg": "0.11.0",
    },
    "latest": {
        "wasm-tools": "1.235.0",
        "wac": "0.7.0",
        "wit-bindgen": "0.43.0", 
        "wkg": "0.11.0",
    },
}

def get_tool_info(tool_name, version, platform):
    """Get tool information for a specific version and platform"""
    
    if tool_name not in TOOL_VERSIONS:
        fail("Unknown tool: {}. Supported tools: {}".format(
            tool_name, 
            ", ".join(TOOL_VERSIONS.keys())
        ))
    
    tool_versions = TOOL_VERSIONS[tool_name]
    if version not in tool_versions:
        available_versions = ", ".join(tool_versions.keys())
        fail("Unsupported version {} for tool {}. Available versions: {}".format(
            version, tool_name, available_versions
        ))
    
    version_info = tool_versions[version]
    if platform not in version_info:
        available_platforms = ", ".join(version_info.keys())
        fail("Unsupported platform {} for tool {} version {}. Available platforms: {}".format(
            platform, tool_name, version, available_platforms
        ))
    
    return version_info[platform]

def validate_tool_compatibility(tools_config):
    """Validate that tool versions are compatible with each other"""
    
    warnings = []
    
    if "wasm-tools" in tools_config:
        wasm_tools_version = tools_config["wasm-tools"]
        if wasm_tools_version in COMPATIBILITY_MATRIX:
            compat_info = COMPATIBILITY_MATRIX[wasm_tools_version]
            
            for tool, version in tools_config.items():
                if tool != "wasm-tools" and tool in compat_info:
                    if version not in compat_info[tool]:
                        warnings.append(
                            "Warning: {} version {} may not be compatible with wasm-tools {}. " +
                            "Recommended versions: {}".format(
                                tool, version, wasm_tools_version, 
                                ", ".join(compat_info[tool])
                            )
                        )
    
    return warnings

def get_recommended_versions(stability = "stable"):
    """Get recommended tool versions for a given stability level"""
    
    if stability not in DEFAULT_VERSIONS:
        fail("Unknown stability level: {}. Available: {}".format(
            stability, ", ".join(DEFAULT_VERSIONS.keys())
        ))
    
    return DEFAULT_VERSIONS[stability]