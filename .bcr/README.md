# BCR (Bazel Central Registry) Configuration

This directory contains template files for publishing `rules_wasm_component` to the Bazel Central Registry.

## Status: ✅ Ready for Publication

**Previous Issue Resolved**: The `git_override` dependency has been removed from `MODULE.bazel` - now using official rules_rust 0.65.0.
See [Issue #7](https://github.com/pulseengine/rules_wasm_component/issues/7) for historical context.

## Files

- **`metadata.template.json`**: Module metadata including maintainers and homepage
- **`source.template.json`**: Source archive configuration
- **`presubmit.yml`**: BCR validation configuration (mirrors our CI exclusions)
- **`README.md`**: This documentation file

## Usage

Once the dependency issue is resolved:

1. Create a GitHub release with proper semantic versioning (e.g., `v1.0.0`)
2. The `.github/workflows/release.yml` workflow will:
   - Generate release notes using git-cliff
   - Create a source archive
   - Publish to GitHub Releases
   - Trigger BCR publication via `.github/workflows/publish-to-bcr.yml`

## Prerequisites for BCR Publication

- [x] Remove `git_override` for `rules_rust` from `MODULE.bazel`
- [x] Use only official registry dependencies
- [ ] Set up `BCR_PUBLISH_TOKEN` secret in repository settings
- [ ] Create fork of `bazel-central-registry` in the `pulseengine` organization

## Testing

The `presubmit.yml` configuration will test the module on:

- **Platforms**: Ubuntu 20.04/22.04, macOS, Windows
- **Bazel versions**: 7.x, latest
- **Targets**: Core functionality (excludes problematic targets with target triple issues)

## Maintenance

Update the template files when:

- Repository URL changes
- Maintainer list changes
- Testing requirements change
- Archive structure changes
