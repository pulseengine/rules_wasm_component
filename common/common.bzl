"""Common constants and utilities"""

# WebAssembly target triples
WASM_TARGET_TRIPLE = "wasm32-wasip2"
WASM_TARGET_TRIPLE_P1 = "wasm32-wasip1"
WASM_TARGET_TRIPLE_UNKNOWN = "wasm32-unknown-unknown"

# File extensions
WASM_EXTENSION = ".wasm"
WIT_EXTENSION = ".wit"

def get_wasm_target(preview2 = True):
    """Get the appropriate WASM target triple"""
    return WASM_TARGET_TRIPLE if preview2 else WASM_TARGET_TRIPLE_P1