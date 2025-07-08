"""Patch for rules_rust to support wasm32-wasip2 target triple"""

def _triple_to_constraint_set_patched(target_triple):
    """Patched version of triple_to_constraint_set that supports wasip2"""

    # Handle special case for wasm32-wasip2
    if target_triple == "wasm32-wasip2":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
        ]

    # Handle special case for wasm32-wasip1
    if target_triple == "wasm32-wasip1":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
        ]

    # For other targets, fall back to original logic
    # This is a simplified version - the real implementation would call the original function
    parts = target_triple.split("-")
    if len(parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-', got: " + target_triple)

    arch = parts[0]
    vendor = parts[1]
    os = parts[2]

    constraints = []

    # Map architecture
    if arch == "wasm32":
        constraints.append("@platforms//cpu:wasm32")
    elif arch == "x86_64":
        constraints.append("@platforms//cpu:x86_64")
    elif arch == "aarch64":
        constraints.append("@platforms//cpu:aarch64")
    else:
        fail("Unsupported architecture: " + arch)

    # Map OS
    if os == "unknown":
        constraints.append("@platforms//os:none")
    elif os == "linux":
        constraints.append("@platforms//os:linux")
    elif os == "darwin":
        constraints.append("@platforms//os:osx")
    elif os == "windows":
        constraints.append("@platforms//os:windows")
    elif os == "wasi":
        constraints.append("@platforms//os:wasi")
    else:
        fail("Unsupported OS: " + os)

    return constraints
