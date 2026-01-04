---
title: WIT-First Development
description: Why the WebAssembly Interface Types (WIT) file should be your starting point
---

# WIT-First Development

<div class="complexity-badge beginner">
  <span class="badge-icon">📐</span>
  <div class="badge-content">
    <strong>CONCEPT</strong>
    <p>Fundamental design philosophy for WebAssembly components</p>
  </div>
</div>

## The Core Principle

**Start with WIT, then implement.** The WebAssembly Interface Types (WIT) file defines what your component does before you write any code. This inverts the traditional approach where implementation comes first and interfaces are extracted later.

```
Traditional:  Code → Extract Interface → Documentation
WIT-First:    WIT Interface → Generate Bindings → Implement
```

## Why WIT First?

### 1. Language Independence

WIT is the universal contract. Any language can implement it:

```wit title="calculator.wit"
package math:calculator@1.0.0;

interface operations {
    add: func(a: f64, b: f64) -> f64;
    divide: func(a: f64, b: f64) -> result<f64, string>;
}

world calculator {
    export operations;
}
```

This single WIT file generates bindings for:
- **Rust**: `impl Guest for Calculator`
- **C++**: `namespace exports::math::calculator::operations`
- **Go**: `func Add(a, b float64) float64`
- **JavaScript**: `export function add(a, b) { ... }`

### 2. Design Before Implementation

WIT forces you to think about your API before writing code:

```wit
// Clear contract - what data flows in and out?
interface user-service {
    record user {
        id: u64,
        name: string,
        email: string,
    }

    // What can fail? Make it explicit.
    create-user: func(name: string, email: string) -> result<user, string>;
    get-user: func(id: u64) -> option<user>;
    delete-user: func(id: u64) -> result<_, string>;
}
```

Questions WIT makes you answer upfront:
- What types do callers need?
- What errors can occur?
- What's optional vs required?
- What are the ownership semantics?

### 3. Automatic Documentation

WIT files are self-documenting contracts:

```wit
package storage:kv@1.0.0;

/// A key-value storage interface for persistent data.
interface store {
    /// A key-value pair with optional TTL.
    record entry {
        key: string,
        value: list<u8>,
        /// Time-to-live in seconds. None means no expiration.
        ttl: option<u32>,
    }

    /// Store a value. Returns the previous value if key existed.
    set: func(entry: entry) -> option<list<u8>>;

    /// Retrieve a value. Returns none if key doesn't exist or expired.
    get: func(key: string) -> option<list<u8>>;

    /// Delete a key. Returns true if key existed.
    delete: func(key: string) -> bool;
}
```

### 4. Composability

WIT interfaces compose naturally:

```wit
package app:backend@1.0.0;

// Import capabilities from other components
world api-server {
    import storage:kv/store;
    import auth:jwt/validator;
    import logging:structured/logger;

    // Export your service
    export user-service;
    export product-service;
}
```

The runtime wires components together based on matching interfaces.

## WIT-First Workflow

### Step 1: Define the Interface

Start with what your component exposes and consumes:

```wit title="wit/greeter.wit"
package demo:greeter@1.0.0;

interface greet {
    /// Generate a personalized greeting.
    greet: func(name: string) -> string;

    /// Generate a formal greeting with title.
    greet-formal: func(title: string, name: string) -> string;
}

world greeter {
    export greet;
}
```

### Step 2: Create WIT Library

```python title="BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "greeter_interface",
    srcs = ["wit/greeter.wit"],
    package_name = "demo:greeter@1.0.0",
)
```

### Step 3: Choose Your Language

The interface is stable. Pick any language:

**Rust:**
```python
rust_wasm_component_bindgen(
    name = "greeter",
    srcs = ["src/lib.rs"],
    wit = ":greeter_interface",
)
```

**C++:**
```python
cpp_component(
    name = "greeter",
    srcs = ["greeter.cpp"],
    wit = "wit/greeter.wit",
    world = "greeter",
)
```

**Go:**
```python
go_wasm_component(
    name = "greeter",
    srcs = ["main.go"],
    wit = ":greeter_interface",
)
```

### Step 4: Implement

Each language implements the same interface differently:

**Rust:**
```rust
impl Guest for Greeter {
    fn greet(name: String) -> String {
        format!("Hello, {}!", name)
    }

    fn greet_formal(title: String, name: String) -> String {
        format!("Good day, {} {}.", title, name)
    }
}
```

**C++:**
```cpp
namespace exports::demo::greeter::greet {

std::string Greet(const std::string& name) {
    return "Hello, " + name + "!";
}

std::string GreetFormal(const std::string& title, const std::string& name) {
    return "Good day, " + title + " " + name + ".";
}

}
```

**Go:**
```go
func Greet(name string) string {
    return "Hello, " + name + "!"
}

func GreetFormal(title, name string) string {
    return "Good day, " + title + " " + name + "."
}
```

## WIT Type System

WIT provides rich types that map to all languages:

### Primitives

| WIT Type | Rust | C++ | Go | JavaScript |
|----------|------|-----|-----|------------|
| `u8`, `u16`, `u32`, `u64` | `u8`, etc. | `uint8_t`, etc. | `uint8`, etc. | `number` |
| `s8`, `s16`, `s32`, `s64` | `i8`, etc. | `int8_t`, etc. | `int8`, etc. | `number` |
| `f32`, `f64` | `f32`, `f64` | `float`, `double` | `float32`, `float64` | `number` |
| `bool` | `bool` | `bool` | `bool` | `boolean` |
| `char` | `char` | `char32_t` | `rune` | `string` |
| `string` | `String` | `std::string` | `string` | `string` |

### Compound Types

```wit
// Records (structs)
record point {
    x: f64,
    y: f64,
}

// Variants (enums with data)
variant shape {
    circle(f64),        // radius
    rectangle(point),   // dimensions
    polygon(list<point>),
}

// Options
option<string>  // Some("value") or None

// Results
result<user, error-code>  // Ok(user) or Err(code)

// Lists
list<u8>       // byte array
list<point>    // array of records

// Tuples
tuple<string, u32>  // fixed-size heterogeneous
```

## Multi-Language Composition

The killer feature of WIT-first: mix languages in one system.

```wit title="wit/system.wit"
package app:system@1.0.0;

// Rust: Performance-critical number crunching
interface compute {
    process-batch: func(data: list<f64>) -> list<f64>;
}

// Go: Simple business logic
interface rules {
    apply-rules: func(input: string) -> string;
}

// JavaScript: Flexible UI templating
interface render {
    render-template: func(template: string, data: string) -> string;
}

world full-system {
    export compute;
    export rules;
    export render;
}
```

Each interface implemented in its ideal language, composed at runtime.

## Best Practices

### 1. Version Your Packages

```wit
package mycompany:api@1.0.0;   // Semantic versioning
package mycompany:api@2.0.0;   // Breaking changes = new major
```

### 2. Use Descriptive Names

```wit
// Good: Clear intent
interface user-authentication {
    authenticate-user: func(credentials: credentials) -> result<session, auth-error>;
}

// Avoid: Vague names
interface auth {
    do-auth: func(data: list<u8>) -> list<u8>;
}
```

### 3. Make Errors Explicit

```wit
// Good: Typed errors
variant database-error {
    not-found,
    connection-failed(string),
    constraint-violation(string),
}

save-user: func(user: user) -> result<user-id, database-error>;

// Avoid: String errors lose information
save-user: func(user: user) -> result<user-id, string>;
```

### 4. Group Related Operations

```wit
// Good: Cohesive interface
interface user-crud {
    create: func(user: new-user) -> result<user, error>;
    read: func(id: user-id) -> option<user>;
    update: func(id: user-id, changes: user-update) -> result<user, error>;
    delete: func(id: user-id) -> result<_, error>;
}

// Avoid: God interface
interface everything {
    create-user: func(...) -> ...;
    send-email: func(...) -> ...;
    process-payment: func(...) -> ...;
    generate-report: func(...) -> ...;
}
```

### 5. Document with Comments

```wit
/// User management service for the application.
///
/// Handles user lifecycle including registration, profile updates,
/// and account deletion. All operations are idempotent.
interface user-service {
    /// Create a new user account.
    ///
    /// Returns the created user with generated ID, or an error if
    /// the email is already registered.
    create-user: func(email: string, name: string) -> result<user, registration-error>;
}
```

## Migration from Code-First

If you have existing code, extract the interface:

1. **Identify the public API** - What functions do callers use?
2. **Write the WIT** - Express those functions in WIT
3. **Generate bindings** - Let wit-bindgen create the glue
4. **Adapt implementation** - Wire your code to the bindings

```
Existing Code    →    Extract API    →    Write WIT    →    Generate Bindings    →    Adapt
(my_lib.rs)           (pub fn...)         (.wit file)       (wit-bindgen)             (impl Guest)
```

## Summary

| Aspect | Code-First | WIT-First |
|--------|-----------|-----------|
| **Starting point** | Implementation | Interface contract |
| **Language coupling** | Tight | Loose |
| **Documentation** | After the fact | Built-in |
| **Composability** | Manual adaptation | Automatic matching |
| **API stability** | Evolves with code | Designed upfront |
| **Multi-language** | Difficult | Natural |

**WIT-first development** treats the interface as a first-class artifact. The WIT file is the source of truth that generates code, not the other way around. This enables true language independence and seamless component composition.

<div class="demo-buttons">
  <a href="/first-component/" class="demo-button">
    Build Your First Component
  </a>
  <a href="/api/wit_defs/" class="demo-button">
    WIT API Reference
  </a>
</div>
