"""Platform definitions and constants for cross-compilation"""

# All supported platforms for tool building
ALL_PLATFORMS = [
    "//platforms:linux_x86_64",
    "//platforms:linux_arm64", 
    "//platforms:macos_x86_64",
    "//platforms:macos_arm64",
    "//platforms:windows_x86_64",
]

# Platform mappings for tool distribution
PLATFORM_MAPPINGS = {
    "//platforms:linux_x86_64": {
        "rust_target": "x86_64-unknown-linux-gnu",
        "os": "linux",
        "arch": "x86_64",
        "suffix": "",
    },
    "//platforms:linux_arm64": {
        "rust_target": "aarch64-unknown-linux-gnu", 
        "os": "linux",
        "arch": "aarch64",
        "suffix": "",
    },
    "//platforms:macos_x86_64": {
        "rust_target": "x86_64-apple-darwin",
        "os": "macos", 
        "arch": "x86_64",
        "suffix": "",
    },
    "//platforms:macos_arm64": {
        "rust_target": "aarch64-apple-darwin",
        "os": "macos",
        "arch": "aarch64", 
        "suffix": "",
    },
    "//platforms:windows_x86_64": {
        "rust_target": "x86_64-pc-windows-msvc",
        "os": "windows",
        "arch": "x86_64", 
        "suffix": ".exe",
    },
}