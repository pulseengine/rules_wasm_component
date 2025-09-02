# Minimal C++ Components with nostdlib

This example demonstrates how to use the `nostdlib` feature in C++ WebAssembly components with custom library linking.

## Problem Solved

Previously, when `nostdlib = True` was used in `cpp_component`, you couldn't specify which libraries to link, making the feature unusable for minimal components that need specific system libraries.

## New `libs` Attribute

The `libs` attribute allows you to specify exactly which libraries to link:

```bazel
cpp_component(
    name = "minimal_component",
    srcs = ["minimal.cpp"],
    wit = "minimal.wit",
    nostdlib = True,       # Disable standard library
    libs = ["m", "c"],     # Link only math and basic C libraries
)
```

## Examples

### 1. Math-Only Component (`minimal_math_component`)
- Uses `nostdlib = True`
- Links only math library: `libs = ["m"]`
- Demonstrates minimal footprint for mathematical operations
- No C++ standard library bloat

### 2. System Component (`minimal_system_component`)
- Uses `nostdlib = True`
- Links multiple libraries: `libs = ["m", "c", "-Wl,--allow-undefined"]`
- Shows both library names and direct linker flags
- Minimal system operations without full stdlib

### 3. Standard Component (`standard_component`)
- Uses `nostdlib = False`  
- Gets standard C++ libraries (-lc++, -lc++abi) automatically
- Additional libraries added via `libs = ["m"]`
- Full standard library available

## Library Specification Formats

The `libs` attribute accepts two formats:

1. **Library names**: `"m"` becomes `"-lm"`
2. **Direct linker flags**: `"-Wl,--allow-undefined"` used as-is

## Build and Test

```bash
# Build minimal math component
bazel build //examples/cpp_component/minimal_nostdlib:minimal_math_component

# Build system component  
bazel build //examples/cpp_component/minimal_nostdlib:minimal_system_component

# Build standard comparison
bazel build //examples/cpp_component/minimal_nostdlib:standard_component

# Validate components export correct WIT interfaces
bazel test //examples/cpp_component/minimal_nostdlib:all
```

## Benefits

- **Smaller binaries**: Only link needed libraries
- **WIT compliance**: Minimal components match WIT specifications exactly
- **Custom control**: Specify exactly which libraries are needed
- **Debugging**: Easier to identify missing dependencies