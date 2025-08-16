# Olareg WASM Component Investigation

## Summary

Investigation into converting [olareg](https://github.com/criminaldou/olareg) to a WebAssembly component for bootstrapping OCI registry tests.

## Olareg Analysis

**✅ PROMISING ASPECTS:**

- Simple, minimal Go codebase (~3000 lines)
- Few external dependencies (spf13/cobra, opencontainers/go-digest)
- Self-contained HTTP server design
- OCI Layout based storage (filesystem)
- Designed for embedding and testing scenarios

**⚠️ CURRENT CHALLENGES:**

1. **WASI Dependencies**: Even basic Go string operations pull in WASI I/O streams
2. **HTTP Server**: Requires WASI HTTP server capabilities (Preview 2 support needed)
3. **Filesystem Access**: Registry storage needs WASI filesystem APIs
4. **TinyGo Limitations**: Current TinyGo WASI Preview 2 support incomplete for full HTTP servers

## Implementation Status

**CURRENT STATE**: Basic proof-of-concept structure created but not functional

- ✅ WIT interface designed for registry operations
- ✅ Go component structure established
- ⚠️ Build fails due to WASI dependency resolution
- ⚠️ HTTP server functionality requires more complete WASI runtime

## Next Steps for Production Implementation

1. **Wait for TinyGo maturity**: Better WASI Preview 2 HTTP support
2. **Alternative approach**: Use Rust with full wasi-http support
3. **Hybrid solution**: Host-provided HTTP with WASM registry logic
4. **Simplified scope**: Registry operations only, not full HTTP server

## Current Working Alternative

For immediate testing, we're using Docker registry:2 on localhost:5001 as our test registry, which provides full OCI compatibility for validating our publishing workflow.

## Recommendation

**DEFER** full olareg WASM implementation until:

- TinyGo has better WASI Preview 2 HTTP support, OR
- Rust implementation path becomes clearer, OR
- Host-provided HTTP adapter pattern is established

The investigation was valuable for understanding the scope and complexity of registry-as-component scenarios.
