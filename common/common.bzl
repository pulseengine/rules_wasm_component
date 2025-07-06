"""Common constants and utilities"""

# WebAssembly target triples
WASM_TARGET_TRIPLE = "wasm32-wasi"  # WASI Preview 1 (supported by rules_rust)
WASM_TARGET_TRIPLE_UNKNOWN = "wasm32-unknown-unknown"

# File extensions
WASM_EXTENSION = ".wasm"
WIT_EXTENSION = ".wit"

def get_wasm_target(unknown = False):
    """Get the appropriate WASM target triple"""
    return WASM_TARGET_TRIPLE_UNKNOWN if unknown else WASM_TARGET_TRIPLE