"""Platform transitions for WASM component builds"""

def _wasm_transition_impl(settings, attr):
    """Transition to WASM platform for component builds"""
    return {
        "//command_line_option:platforms": "//platforms:wasm32-wasi",
    }

wasm_transition = transition(
    implementation = _wasm_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
    ],
)

def _wasm_unknown_transition_impl(settings, attr):
    """Transition to WASM unknown platform for bare metal builds"""
    return {
        "//command_line_option:platforms": "//platforms:wasm32-unknown-unknown",
    }

wasm_unknown_transition = transition(
    implementation = _wasm_unknown_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
    ],
)