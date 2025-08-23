# JavaScript/TypeScript WebAssembly Components Example

This example demonstrates how to build WebAssembly components from JavaScript and TypeScript source code using jco (JavaScript Component Tools).

## Overview

The JavaScript component rules provide:

1. **`js_component`** - Compiles JavaScript/TypeScript to WebAssembly components
2. **`jco_transpile`** - Converts WebAssembly components back to JavaScript bindings
3. **`npm_install`** - Manages NPM dependencies for JavaScript components

## Example Structure

```
examples/js_component/
├── BUILD.bazel           # Build configuration
├── package.json          # NPM dependencies
├── src/                  # Source files
│   ├── index.js         # JavaScript component
│   ├── utils.js         # Utility functions
│   ├── calculator.ts    # TypeScript component
│   └── types.ts         # TypeScript types
├── wit/                 # WIT interface definitions
│   ├── hello.wit       # Hello component interface
│   └── calculator.wit  # Calculator component interface
└── README.md           # This file
```

## Building Components

### JavaScript Component

```starlark
js_component(
    name = "hello_js_component",
    srcs = [
        "src/index.js",
        "src/utils.js",
    ],
    wit = "wit/hello.wit",
    entry_point = "index.js",
    package_name = "example:hello@1.0.0",
    npm_dependencies = {
        "lodash": "^4.17.21",
    },
    optimize = True,
)
```

### TypeScript Component

```starlark
js_component(
    name = "calc_ts_component",
    srcs = [
        "src/calculator.ts",
        "src/types.ts",
    ],
    wit = "wit/calculator.wit",
    entry_point = "calculator.ts",
    package_name = "example:calculator@1.0.0",
    world = "calculator",
    optimize = True,
    minify = True,
)
```

## Toolchain Configuration

The jco toolchain can be configured using different strategies:

### System Installation

```starlark
# MODULE.bazel
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(strategy = "npm")
```

### NPM Installation

```starlark
# MODULE.bazel
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(strategy = "npm", version = "1.4.0")
```

### Direct Download

```starlark
# MODULE.bazel
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(strategy = "download", version = "1.4.0")
```

## Building

```bash
# Build JavaScript component
bazel build //examples/js_component:hello_js_component

# Build TypeScript component
bazel build //examples/js_component:calc_ts_component

# Generate JavaScript bindings from component
bazel build //examples/js_component:hello_js_bindings

# Install NPM dependencies
bazel build //examples/js_component:npm_deps
```

## Features

### NPM Dependencies

Components can use NPM packages by specifying them in `npm_dependencies` or `package.json`:

```javascript
import _ from "lodash";

export function processName(name) {
  return _.capitalize(name);
}
```

### TypeScript Support

Full TypeScript support with type checking and compilation:

```typescript
interface Operation {
  op: "add" | "subtract" | "multiply" | "divide";
  a: number;
  b: number;
}

export function calculate(operation: Operation): CalculationResult {
  // Implementation...
}
```

### WIT Interface Binding

Components automatically implement WIT interfaces:

```wit
interface hello {
    say-hello: func(name: string) -> string;
    greet-multiple: func(names: list<string>) -> list<string>;
}
```

### Component Optimization

Built-in optimization and minification:

```starlark
js_component(
    name = "optimized_component",
    optimize = True,    # Enable optimizations
    minify = True,      # Minify output
    compat = True,      # Browser compatibility
)
```

## Requirements

- **jco**: JavaScript Component Tools
- **Node.js**: Runtime for JavaScript execution
- **npm**: Package manager for dependencies
- **TypeScript**: For TypeScript component support (optional)

## Installation

> **Recommended**: All tools are now downloaded automatically by Bazel for hermetic builds. No manual installation required!

```starlark
# MODULE.bazel - Automatic hermetic setup
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

<details>
<summary>Alternative: Manual Installation</summary>

If you prefer manual installation (not recommended for production):

```bash
npm install -g @bytecodealliance/jco
```

</details>

## Integration with Other Components

JavaScript components can be used with other rules in the ecosystem:

```starlark
# Compose with other components
wac_compose(
    name = "full_system",
    components = {
        "frontend": ":hello_js_component",
        "backend": "//rust:backend_component",
    },
)

# Use in remote compositions
wac_remote_compose(
    name = "distributed_app",
    local_components = {
        "ui": ":hello_js_component",
    },
    remote_components = {
        "auth": "registry/auth@1.0.0",
    },
)
```

## Troubleshooting

- Ensure Node.js and npm are installed
- All tools are downloaded automatically by Bazel (hermetic builds)
- Verify WIT interface matches exported functions
- Use `--verbose` flag with bazel for detailed error messages
