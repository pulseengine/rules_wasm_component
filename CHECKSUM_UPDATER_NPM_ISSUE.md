# Checksum Updater NPM Tool Support Issue

**Date**: 2025-11-14
**Root Cause**: Checksum updater cannot parse npm-based tool definitions
**Affected Issues**: #194, #197, #203 (all closed as duplicates)

## Problem

The `tools/checksum_updater` binary fails with:
```
Error: Failed to parse JSON for tool: jco
```

## Root Cause Analysis

The checksum_updater tool was designed for GitHub binary downloads with a standard schema, but `jco` uses npm for distribution and has a different JSON schema.

### Standard Schema (Works)

Used by: wasm-tools, wit-bindgen, wac, wkg, wasmtime, wizer, etc.

```json
{
  "tool_name": "wasm-tools",
  "github_repo": "bytecodealliance/wasm-tools",
  "latest_version": "1.240.0",
  "supported_platforms": [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
    "windows_amd64"
  ],
  "versions": {
    "1.240.0": {
      "release_date": "2024-10-09",
      "platforms": {
        "darwin_arm64": {
          "sha256": "b65777dcb9873b404e50774b54b61b703eb980cadb20ada175a8bf74bfe23706",
          "url_suffix": "aarch64-macos.tar.gz"
        }
      }
    }
  }
}
```

### NPM Schema (Fails)

Used by: jco (only one currently)

```json
{
  "tool_name": "jco",
  "github_repo": "bytecodealliance/jco",
  "latest_version": "1.4.0",
  "install_method": "download_nodejs_then_npm",
  "requires": ["nodejs"],
  "versions": {
    "1.4.0": {
      "release_date": "2024-11-25",
      "platforms": {
        "universal": {
          "npm_package": "@bytecodealliance/jco",
          "npm_version": "1.4.0",
          "dependencies": ["@bytecodealliance/componentize-js"]
        }
      }
    }
  }
}
```

**Key differences:**
- No `supported_platforms` array (has `install_method` instead)
- Platform key is `"universal"` not architecture-specific
- Has `npm_package` instead of `sha256`/`url_suffix`

## Fix Options

### Option 1: Add NPM Tool Support to Checksum Updater ⭐ RECOMMENDED

**Pros:**
- Properly handles npm packages
- Enables automated updates for npm-based tools
- Follows the existing architecture

**Implementation:**
1. Add npm tool schema parsing to `tools/checksum_updater/src/lib.rs`
2. Handle `install_method = "download_nodejs_then_npm"` case
3. Query npm registry for version updates instead of GitHub releases
4. Store npm package info instead of checksums

**Code location**: `tools/checksum_updater/src/lib.rs`

### Option 2: Exclude NPM Tools from Automated Updates

**Pros:**
- Quick fix
- No code changes needed

**Cons:**
- jco won't get automated version updates
- Manual updates required

**Implementation:**
Update `.github/workflows/checksum-update.yml` to exclude jco:
```yaml
env:
  EXCLUDED_TOOLS: "jco"  # npm-based tools excluded
```

### Option 3: Convert jco to Standard Schema (NOT RECOMMENDED)

**Cons:**
- Doesn't match how jco is actually distributed (via npm)
- Creates confusion between schema and reality
- Loses npm-specific metadata

## Recommended Solution

**Implement Option 1** - Add proper NPM tool support:

```rust
// In tools/checksum_updater/src/lib.rs

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
enum ToolDefinition {
    GitHubBinary(GitHubBinaryTool),
    NpmPackage(NpmPackageTool),
}

#[derive(Debug, Serialize, Deserialize)]
struct NpmPackageTool {
    tool_name: String,
    github_repo: Option<String>,
    latest_version: String,
    install_method: String, // "download_nodejs_then_npm"
    requires: Vec<String>,
    versions: HashMap<String, NpmVersionInfo>,
}

#[derive(Debug, Serialize, Deserialize)]
struct NpmVersionInfo {
    release_date: String,
    platforms: HashMap<String, NpmPlatformInfo>,
}

#[derive(Debug, Serialize, Deserialize)]
struct NpmPlatformInfo {
    npm_package: String,
    npm_version: String,
    dependencies: Vec<String>,
}
```

**Update logic:**
1. Parse tool JSON using `ToolDefinition` enum (untagged)
2. For NPM tools, query npm registry API:
   ```
   GET https://registry.npmjs.org/@bytecodealliance/jco
   ```
3. Check for newer versions
4. Update JSON with new version info

## Temporary Workaround

Until npm support is implemented, the weekly checksum update workflow will continue to fail on jco. This is **not critical** because:

1. jco is installed via hermetic Node.js + npm (not from checksums)
2. The version is pinned in `toolchains/jco_toolchain.bzl`
3. Manual updates are straightforward

## Impact

**Current**: Weekly automated checksum updates fail with non-critical error
**After Fix**: All tools (including npm-based ones) get automated version tracking

## Files Involved

- `checksums/tools/jco.json` - NPM tool definition
- `tools/checksum_updater/src/lib.rs` - Updater implementation
- `.github/workflows/checksum-update.yml` - Weekly automation
- `toolchains/jco_toolchain.bzl` - JCO installation logic

## Testing

After implementing npm support:

```bash
# Test npm tool parsing
bazel run //tools/checksum_updater:checksum_updater_bin -- validate checksums/tools/jco.json

# Test update check
bazel run //tools/checksum_updater:checksum_updater_bin -- update --tools jco --dry-run

# Full integration test
bazel test //tools/checksum_updater:integration_test
```

## Related Issues

- Closed #194 - Weekly checksum update failed (2025-10-27)
- Closed #197 - Weekly checksum update failed (2025-11-03)
- Closed #203 - Weekly checksum update failed (2025-11-10)

All three had the same root cause: jco.json parsing failure.
