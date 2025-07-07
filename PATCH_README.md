# rules_rust WASI Support Patch

This repository uses a fork of rules_rust with minimal patches to support WASI target triples.

## What's Patched

**File**: `rust/platform/triple.bzl`  
**Changes**: Added support for 2-component WASI target triples

### The Problem
rules_rust expects target triples to have 3+ components (e.g., `x86_64-unknown-linux-gnu`), but WASI targets use 2-component format:
- `wasm32-wasip1` (WASI Preview 1)
- `wasm32-wasip2` (WASI Preview 2)

### The Solution
Convert 2-component WASI targets to standard 3-component format:
- `wasm32-wasip1` → `wasm32-unknown-wasi`  
- `wasm32-wasip2` → `wasm32-unknown-wasi`
- `wasm32-wasip3` → `wasm32-unknown-wasi` (future support)

## Applying the Patch

1. Clone the rules_rust fork:
   ```bash
   git clone https://github.com/avrabe/rules_rust.git
   cd rules_rust
   ```

2. Apply the patch:
   ```bash
   git apply wasip2-support.patch
   ```

3. Commit and push:
   ```bash
   git add rust/platform/triple.bzl
   git commit -m "feat: add support for wasm32-wasip2 target triples

   - Handle 2-component WASI target triples in triple.bzl
   - Convert wasm32-wasip1, wasm32-wasip2, wasm32-wasip3 to standard format
   - Enable WASI Preview 2 builds with rules_rust compatibility"
   git push origin main
   ```

4. Update the commit hash in `MODULE.bazel`:
   ```python
   git_override(
       module_name = "rules_rust",
       remote = "https://github.com/avrabe/rules_rust.git", 
       commit = "abc123...",  # Use the actual commit hash
   )
   ```

## Status

This is a minimal, safe patch that only affects target triple parsing. The changes are expected to be upstreamed to the main rules_rust repository eventually.