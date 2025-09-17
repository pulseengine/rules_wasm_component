# Contributing to rules_wasm_component

We welcome contributions to the rules_wasm_component project! This document provides guidelines for contributing.

## Development Setup

### Prerequisites

- **Bazel 7.0+** with bzlmod support
- **Rust 1.75+** with WASM targets

### Installation

```bash
# Clone the repository
git clone https://github.com/pulseengine/rules_wasm_component.git
cd rules_wasm_component

# Install Rust and WASM targets
rustup target add wasm32-wasip2 wasm32-wasip1 wasm32-unknown-unknown

# Verify setup - all tools downloaded automatically by Bazel
bazel build //...
bazel test //...
```

> **Note**: All WASM tools (`wasm-tools`, `wac-cli`, `wit-bindgen-cli`, etc.) are now downloaded automatically by Bazel
> for truly hermetic builds. No manual installation required!

## Contributing Guidelines

### Code Style

- **Starlark**: Follow [Starlark style guide](https://bazel.build/rules/bzl-style)
- **Documentation**: All public rules must have comprehensive docstrings
- **Examples**: Add examples for new features
- **Tests**: Include tests for new functionality

### Formatting

```bash
# Format all files
bazel run //:buildifier

# Check formatting
bazel run //:buildifier -- --mode=check
```

### Testing

```bash
# Run all tests
bazel test //...

# Test specific area
bazel test //wit/...
bazel test //rust/...
bazel test //wac/...

# Integration tests
bazel test //examples/...
```

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/my-new-feature
```

### 2. Implement Changes

- **Add rule implementation** in appropriate directory
- **Update providers** if needed for new data
- **Add BUILD.bazel** files for new packages
- **Write comprehensive documentation**

### 3. Add Tests

```bash
# Example test structure
my_feature/
├── BUILD.bazel          # Test targets
├── my_feature.bzl       # Implementation
├── my_feature_test.bzl  # Unit tests
└── test_data/           # Test fixtures
```

### 4. Update Examples

```bash
# Add example usage
examples/my_feature/
├── BUILD.bazel
├── src/
└── README.md
```

### 5. Update Documentation

- **Rule reference** in `docs/rules.md`
- **Migration guide** if changing existing APIs
- **README.md** for major features

## Rule Development Guidelines

### Provider Design

```starlark
# Good: Clear field documentation
MyInfo = provider(
    doc = "Information about my feature",
    fields = {
        "my_field": "Description of what this field contains",
        "my_list": "List of items with specific purpose",
    },
)

# Bad: Unclear or missing documentation
MyInfo = provider(fields = {"stuff": "some stuff"})
```

### Rule Implementation

```starlark
def _my_rule_impl(ctx):
    """Implementation with clear documentation"""

    # Validate inputs
    if not ctx.files.srcs:
        fail("srcs cannot be empty")

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:my_toolchain_type"]

    # Declare outputs
    output = ctx.actions.declare_file(ctx.label.name + ".out")

    # Run action
    ctx.actions.run(
        executable = toolchain.my_tool,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "MyAction",
        progress_message = "Processing %s" % ctx.label,
    )

    return [DefaultInfo(files = depset([output]))]

my_rule = rule(
    implementation = _my_rule_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".my_ext"],
            mandatory = True,
            doc = "Source files to process",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:my_toolchain_type"],
    doc = """
    Processes my files into output format.

    This rule takes source files and processes them using my_tool.

    Example:
        my_rule(
            name = "process_files",
            srcs = ["file1.my_ext", "file2.my_ext"],
        )
    """,
)
```

### Error Handling

```starlark
# Good: Clear error messages
if not ctx.files.srcs:
    fail("my_rule requires at least one source file in 'srcs'")

if ctx.attr.profile not in ["debug", "release"]:
    fail("profile must be 'debug' or 'release', got: %s" % ctx.attr.profile)

# Bad: Unclear errors
fail("invalid input")
fail("error")
```

## Testing Guidelines

### Unit Tests

```starlark
# my_rule_test.bzl
load("@bazel_skylib//lib:unittest.bzl", "unittest")
load(":my_rule.bzl", "my_rule")

def _my_rule_test_impl(ctx):
    env = unittest.begin(ctx)

    # Test successful case
    # ... test implementation

    return unittest.end(env)

my_rule_test = unittest.make(_my_rule_test_impl)

def my_rule_test_suite():
    unittest.suite(
        "my_rule_tests",
        my_rule_test,
    )
```

### Integration Tests

```starlark
# BUILD.bazel
load(":my_rule.bzl", "my_rule")

my_rule(
    name = "test_basic",
    srcs = ["test_input.txt"],
)

sh_test(
    name = "integration_test",
    srcs = ["integration_test.sh"],
    data = [":test_basic"],
)
```

## Documentation Standards

### Rule Documentation

```starlark
my_rule = rule(
    # ... implementation
    doc = """
    One-line summary of what the rule does.

    Longer description explaining the purpose, behavior,
    and any important details about the rule.

    Example:
        my_rule(
            name = "example",
            srcs = ["file.txt"],
            options = ["--verbose"],
        )

    Args:
        name: Target name
        srcs: Source files to process
        options: Additional command-line options
    """,
)
```

### API Documentation

- **All public rules** must have comprehensive docstrings
- **Attributes** must be documented with clear descriptions
- **Examples** should show realistic usage patterns
- **Cross-references** to related rules and providers

## Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create feature branch** from `main`
3. **Implement changes** following guidelines
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Submit pull request** with clear description

### PR Requirements

- ✅ All tests pass
- ✅ Code is formatted (buildifier)
- ✅ Documentation is updated
- ✅ Examples work correctly
- ✅ No breaking changes (or clearly documented)

### Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Address feedback** and update PR
4. **Final approval** and merge

## Release Process

### Version Management

- **Semantic versioning**: `MAJOR.MINOR.PATCH`
- **Breaking changes**: Increment MAJOR
- **New features**: Increment MINOR
- **Bug fixes**: Increment PATCH

### Release Checklist

- [ ] Update version in `MODULE.bazel`
- [ ] Update `CHANGELOG.md`
- [ ] Tag release: `git tag v1.2.3`
- [ ] Update documentation
- [ ] Announce release

## Getting Help

### Communication Channels

- **Issues**: GitHub issues for bugs and feature requests
- **Discussions**: GitHub discussions for questions
- **Email**: <maintainers@rules-wasm-component.dev>

### Common Issues

- **Toolchain not found**: Ensure WASM tools are installed
- **Build failures**: Check Rust and Bazel versions
- **Test failures**: Run `bazel clean` and retry

## Project Structure

```text
rules_wasm_component/
├── BUILD.bazel          # Root build file
├── MODULE.bazel         # Bazel module definition
├── README.md            # Project overview
├── CONTRIBUTING.md      # This file
├── wit/                 # WIT-related rules
├── rust/                # Rust WASM component rules
├── wac/                 # WAC composition rules
├── wasm/                # General WASM utilities
├── toolchains/          # Toolchain definitions
├── providers/           # Provider definitions
├── common/              # Common utilities
├── examples/            # Usage examples
├── docs/                # Documentation
└── .github/             # CI/CD workflows
```

Thank you for contributing to rules_wasm_component! 🎉
