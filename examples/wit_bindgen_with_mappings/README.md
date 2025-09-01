# WIT Bindgen with Interface Mappings Example

This example demonstrates the enhanced `wit_bindgen` rule with sophisticated interface mapping capabilities using the `--with` parameter from wit-bindgen CLI.

## Key Features Demonstrated

### 1. Interface Mapping (`with_mappings`)

Map WIT interfaces to existing Rust modules instead of generating new code:

```starlark
wit_bindgen(
    name = "advanced_bindings",
    wit = ":api_interfaces", 
    with_mappings = {
        # Map WASI interfaces to existing crates
        "wasi:http/types": "wasi::http::types",
        "wasi:io/poll": "wasi::io::poll",
        "wasi:filesystem/types": "wasi::filesystem::types",
        # Generate our custom interfaces
        "example:api/service": "generate",
    },
)
```

**Benefits:**
- Reduce code size by reusing existing implementations
- Ensure compatibility with ecosystem crates
- Control which interfaces are generated vs. mapped

### 2. Ownership Models (`ownership`)

Control how wit-bindgen handles memory and borrowing:

```starlark
ownership = "borrowing"  # or "owning", "borrowing-duplicate-if-necessary"
```

### 3. Custom Derives (`additional_derives`)

Add derive attributes to generated types:

```starlark
additional_derives = ["Clone", "Debug", "PartialEq", "Serialize", "Deserialize"]
```

### 4. Async Interface Support (`async_interfaces`)

Enable async/await patterns for better ergonomics:

```starlark
async_interfaces = ["example:api/service#async-process"]  # Specific methods
# or
async_interfaces = ["all"]  # All interfaces
```

### 5. Code Formatting (`format_code`)

Automatically format generated code:

```starlark
format_code = True
```

### 6. Generation Control (`generate_all`)

Control whether to generate all interfaces or only those not mapped:

```starlark
generate_all = False  # Only generate interfaces not in with_mappings
```

## Example Configurations

### Basic Usage (No Mappings)
```starlark
wit_bindgen(
    name = "basic_bindings",
    language = "rust",
    wit = ":api_interfaces",
)
```

### Advanced with Interface Mappings
```starlark
wit_bindgen(
    name = "advanced_bindings", 
    language = "rust",
    wit = ":api_interfaces",
    with_mappings = {
        "wasi:http/types": "wasi::http::types",
        "wasi:io/poll": "wasi::io::poll", 
        "example:api/service": "generate",
    },
    ownership = "borrowing",
    additional_derives = ["Clone", "Debug", "PartialEq"],
    async_interfaces = ["example:api/service#async-process"],
)
```

### Comprehensive Configuration
```starlark
wit_bindgen(
    name = "full_featured_bindings",
    language = "rust", 
    wit = ":api_interfaces",
    with_mappings = {
        "wasi:http/types": "http::types",
        "example:api/logging": "tracing",
        "example:api/service": "generate",
    },
    ownership = "borrowing-duplicate-if-necessary",
    additional_derives = ["Clone", "Debug", "Serialize", "Deserialize"],
    async_interfaces = ["all"],
    format_code = True,
    generate_all = True,
    options = ["--skip-format", "--verbose"],
)
```

## Files Structure

```
examples/wit_bindgen_with_mappings/
├── BUILD.bazel              # Build configuration with multiple wit_bindgen examples
├── api.wit                  # WIT interface definitions with WASI dependencies
├── src/
│   └── client.rs           # Example Rust code using the generated bindings
├── tests/
│   └── bindings_test.rs    # Comprehensive tests validating all features
└── README.md               # This documentation
```

## Running the Example

```bash
# Build all bindings
bazel build //examples/wit_bindgen_with_mappings:all

# Run the tests to validate functionality
bazel test //examples/wit_bindgen_with_mappings:bindings_test

# Build the client library using advanced bindings
bazel build //examples/wit_bindgen_with_mappings:api_client
```

## Key Insights

### Interface Mapping Patterns

1. **Existing Crates**: `"wasi:io/poll": "wasi::io::poll"`
   - Reuse existing ecosystem implementations
   - Reduce binary size and compilation time

2. **Custom Type Mapping**: `"my:pkg/types": "crate::custom::Types"`
   - Map to your own type definitions
   - Maintain consistency across components

3. **Generate New**: `"example:api/service": "generate"`
   - Generate fresh bindings for new interfaces
   - Full control over custom business logic

### Ownership Model Benefits

- **`owning`**: Full ownership, simpler but potentially more memory usage
- **`borrowing`**: References where possible, more efficient
- **`borrowing-duplicate-if-necessary`**: Best of both worlds

### Async Interface Advantages

```rust
// Without async_interfaces
let result = connection.process(input); // Blocking

// With async_interfaces
let result = connection.process(input).await; // Non-blocking
```

## Testing Strategy

The example includes comprehensive tests that validate:

1. **Compile-time validation**: Generated types exist and are usable
2. **Custom derives**: Clone, Debug, PartialEq work correctly
3. **Ownership models**: Borrowing patterns work as expected  
4. **Interface mappings**: Mapped vs. generated interfaces behave correctly
5. **Cross-binding comparison**: Different configurations produce equivalent core functionality

## Migration from Basic to Advanced

```diff
wit_bindgen(
    name = "my_bindings",
    language = "rust",
    wit = ":interfaces",
+   with_mappings = {
+       "wasi:io/poll": "wasi::io::poll",
+       "my:api/service": "generate", 
+   },
+   ownership = "borrowing",
+   additional_derives = ["Clone", "Debug"],
+   async_interfaces = ["my:api/service#async-method"],
+   format_code = True,
)
```

This demonstrates the complete wit-bindgen enhancement, enabling sophisticated interface mapping patterns that reduce code generation overhead while maintaining full compatibility with the WebAssembly Component Model ecosystem.