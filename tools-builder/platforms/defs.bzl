"""Platform definitions and constants for cross-compilation"""

# All supported platforms for tool building (starting with host platform only)
# TODO: Add full cross-compilation matrix once LLVM toolchain for Linux is configured
ALL_PLATFORMS = [
    # Only build for current host platform to start
    "@platforms//host",
]

# Platform mappings for tool distribution
PLATFORM_MAPPINGS = {
    # Host platform (detected automatically by Bazel)
    "@platforms//host": {
        "rust_target": "host",  # Let Rust toolchain detect automatically
        "os": "host",
        "arch": "host",
        "suffix": "",
    },
    # Cross-compilation platforms (for future use)
    "@rules_wasm_component//platforms:linux_x86_64": {
        "rust_target": "x86_64-unknown-linux-gnu",
        "os": "linux",
        "arch": "x86_64",
        "suffix": "",
    },
    "@rules_wasm_component//platforms:linux_arm64": {
        "rust_target": "aarch64-unknown-linux-gnu",
        "os": "linux",
        "arch": "aarch64",
        "suffix": "",
    },
    "@rules_wasm_component//platforms:macos_x86_64": {
        "rust_target": "x86_64-apple-darwin",
        "os": "macos",
        "arch": "x86_64",
        "suffix": "",
    },
    "@rules_wasm_component//platforms:macos_arm64": {
        "rust_target": "aarch64-apple-darwin",
        "os": "macos",
        "arch": "aarch64",
        "suffix": "",
    },
    "@rules_wasm_component//platforms:windows_x86_64": {
        "rust_target": "x86_64-pc-windows-msvc",
        "os": "windows",
        "arch": "x86_64",
        "suffix": ".exe",
    },
}
