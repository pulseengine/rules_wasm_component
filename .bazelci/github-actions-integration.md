# GitHub Actions Integration with Buildkite CI

This document explains how to integrate the Buildkite CI configuration with your existing GitHub Actions workflow for comprehensive testing coverage.

## Integration Strategy

### Complementary Testing Approach

The existing GitHub Actions workflow (`.github/workflows/ci.yml`) and the new Buildkite CI configuration (`.bazelci/presubmit.yml`) work together to provide comprehensive testing:

**GitHub Actions** - Fast feedback and basic validation:
- Quick lint and format checks
- Basic build and test validation on Linux and macOS
- Essential WebAssembly component validation
- Integration tests for core functionality

**Buildkite CI** - Comprehensive testing matrix:
- Multi-platform testing (including Windows)
- Multiple Bazel versions (minimum, current, rolling)
- Various configuration combinations (bzlmod vs WORKSPACE)
- Specialized WebAssembly testing (WASI, component model)
- Performance and optimization testing

## Recommended Workflow Changes

### 1. Update GitHub Actions for Buildkite Integration

Add Buildkite status checks to your GitHub Actions workflow:

```yaml
# Add to .github/workflows/ci.yml
buildkite_trigger:
  name: Trigger Buildkite CI
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  
  steps:
  - name: Trigger Buildkite Build
    uses: buildkite/trigger-pipeline-action@v1.5.0
    with:
      buildkite_api_access_token: ${{ secrets.BUILDKITE_API_ACCESS_TOKEN }}
      pipeline: "your-org/rules-wasm-component"
      commit: ${{ github.event.pull_request.head.sha }}
      branch: ${{ github.event.pull_request.head.ref }}
      message: "PR #${{ github.event.pull_request.number }}: ${{ github.event.pull_request.title }}"
```

### 2. Configure Branch Protection Rules

In your GitHub repository settings, add Buildkite checks as required status checks:

- Navigate to Settings → Branches → Branch protection rules
- Add required status checks for critical Buildkite jobs:
  - `ubuntu2204`
  - `macos_arm64` 
  - `examples_ubuntu2204`
  - `integration_tests`
  - `bcr_test`

### 3. Parallel Execution Strategy

Configure workflows to run in parallel for faster feedback:

```yaml
# Updated strategy in .github/workflows/ci.yml
jobs:
  # Keep existing fast checks
  lint:
    name: Lint and Format Check
    runs-on: ubuntu-latest
    # ... existing configuration

  # Simplified GitHub Actions tests for speed
  quick_test:
    name: Quick Test on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    needs: lint
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    # ... focused on essential tests only

  # Buildkite trigger (runs in parallel)
  buildkite_comprehensive:
    name: Comprehensive Testing (Buildkite)
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    # ... trigger Buildkite pipeline
```

## Buildkite Setup

### 1. Pipeline Configuration

Create a Buildkite pipeline with the following configuration:

```yaml
# buildkite.yml (in your Buildkite pipeline settings)
env:
  BUILDKITE_CLEAN_CHECKOUT: true

steps:
  - label: ":bazel: Bazel CI"
    plugins:
      - bazelbuild/bazel-ci:
          config: .bazelci/presubmit.yml
```

### 2. Agent Configuration

Ensure your Buildkite agents have the necessary tools:

```bash
# Agent setup script
#!/bin/bash

# Install Bazelisk
curl -Lo /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
chmod +x /usr/local/bin/bazel

# Install Rust (will be done per-job but can be cached)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install system dependencies
apt-get update && apt-get install -y build-essential git curl
```

### 3. Environment Variables

Configure the following environment variables in Buildkite:

- `BUILDKITE_API_ACCESS_TOKEN`: For GitHub integration
- `BAZEL_CACHE_URL`: Optional remote cache URL
- `RUST_CACHE_DIR`: Optional Rust toolchain cache

## Testing Matrix Coordination

### GitHub Actions (Fast Lane)
```yaml
# Focus on essential, fast tests
test_matrix:
  platform: [ubuntu-latest, macos-latest]
  targets:
    - "//examples/basic:hello_component"
    - "//rust/..."
    - "//test/unit/..."
```

### Buildkite CI (Comprehensive Lane)
```yaml
# Full matrix testing
test_matrix:
  platform: [ubuntu2204, macos_arm64, windows]
  bazel_version: [minimum, current, rolling]
  configuration: [bzlmod, no_bzlmod, optimized, clippy]
  targets: ["//..."]
```

## Status Reporting Integration

### 1. GitHub Status Checks

Configure Buildkite to report status back to GitHub:

```yaml
# In your Buildkite pipeline
plugins:
  - seek-oss/github-commit-status#v2.0.0:
      context: "buildkite/rules-wasm-component"
```

### 2. Slack/Teams Integration

Optional: Add notifications for CI status:

```yaml
# Buildkite pipeline notification
notify:
  - slack: "#engineering"
    if: build.state == "failed"
```

## Caching Strategy

### 1. Bazel Remote Cache

Configure shared caching between GitHub Actions and Buildkite:

```bash
# .bazelrc additions for CI
build:ci --remote_cache=https://your-cache-url
build:ci --remote_timeout=10s
build:ci --remote_accept_cached=true
build:ci --remote_upload_local_results=true
```

### 2. Rust Toolchain Cache

Cache Rust installations across builds:

```yaml
# GitHub Actions caching
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      ~/.rustup
    key: ${{ runner.os }}-rust-${{ hashFiles('MODULE.bazel') }}
```

## Debugging CI Failures

### 1. Local Reproduction

For Buildkite failures, reproduce locally:

```bash
# Use the exact same configuration
export BAZEL_VERSION="7.4.1"  # From failed job
bazel test //... --platforms=//platforms:wasm32-wasi --config=wasm_component

# Check specific example
bazel build //examples/basic:hello_component
wasm-tools validate bazel-bin/examples/basic/hello_component.wasm
```

### 2. Buildkite Logs

Access detailed logs in Buildkite UI:
- Build timeline view
- Artifact downloads
- Raw log outputs
- Performance metrics

### 3. GitHub Actions Comparison

Compare with GitHub Actions results:
- Same commit, different environment results
- Platform-specific differences
- Timing and resource usage variations

## Migration Strategy

### Phase 1: Parallel Testing
- Keep existing GitHub Actions
- Add Buildkite CI as additional testing
- Monitor for inconsistencies

### Phase 2: Gradual Migration
- Move comprehensive tests to Buildkite
- Keep fast feedback in GitHub Actions
- Update branch protection rules

### Phase 3: Optimization
- Fine-tune test distribution
- Optimize cache usage
- Minimize redundant testing

## Cost Optimization

### 1. Selective Testing
```yaml
# Only run full matrix on main branch
if: build.branch == "main" || build.pull_request.draft == false
```

### 2. Resource Management
```yaml
# Use appropriate agent sizes
agents:
  queue: "high-memory"  # For resource-intensive jobs
  queue: "default"      # For standard jobs
```

### 3. Parallel Execution Limits
```yaml
# Prevent resource exhaustion
parallelism: 3  # Limit concurrent jobs
```

This integration provides comprehensive testing coverage while maintaining fast feedback loops for developers.