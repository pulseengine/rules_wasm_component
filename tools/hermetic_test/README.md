# Hermiticity Testing Tools

Tools to verify that Bazel builds are truly hermetic and don't depend on system-installed tools or user-specific paths.

## What is Hermiticity?

A hermetic build:
- ✅ Only accesses files within Bazel's control (bazel-*, external/)
- ✅ Uses toolchains managed by Bazel
- ✅ Produces identical outputs regardless of host environment
- ❌ Doesn't access `/usr/local/`, `$HOME/.cargo`, system tools, etc.

## Testing Approaches

### 1. System Tracing (Recommended for Deep Analysis)

#### macOS (fs_usage)

```bash
# Test a specific target
sudo ./tools/hermetic_test/macos_hermetic_test.sh //examples/rust_hello:rust_hello_component

# Or use the cross-platform wrapper
sudo ./tools/hermetic_test/hermetic_test.sh //examples/rust_hello:rust_hello_component
```

**Requirements:** sudo access (fs_usage requires root)

#### Linux (strace)

```bash
# Test a specific target
./tools/hermetic_test/linux_hermetic_test.sh //examples/rust_hello:rust_hello_component

# Or use the cross-platform wrapper
./tools/hermetic_test/hermetic_test.sh //examples/rust_hello:rust_hello_component
```

**Requirements:** strace installed (`apt-get install strace` or `dnf install strace`)

### 2. Bazel Execution Log (No Root Required)

```bash
# Build with execution log
bazel build --execution_log_json_file=/tmp/exec.log //examples/rust_hello:rust_hello_component

# Analyze the log
python3 tools/hermetic_test/analyze_exec_log.py /tmp/exec.log
```

**Advantages:**
- No sudo required
- Cross-platform (works on macOS, Linux, Windows)
- Pure Bazel approach
- Shows exactly what Bazel actions execute

### 3. Bazel Clean + Offline Build

```bash
# Test that build works completely offline
bazel clean
bazel build --repository_cache=/tmp/empty_cache --nofetch //examples/rust_hello:rust_hello_component
```

If this fails, the build depends on external network access during build (non-hermetic).

## Understanding Results

### ✅ Good (Hermetic)
```
Accessing: /private/var/tmp/_bazel_r/c75668b3c4b0dcda1653a0b057295de5/...
Accessing: /Users/r/git/rules_wasm_component/bazel-out/...
```

### ⚠️ Suspicious (Potentially Non-Hermetic)
```
Accessing: /usr/local/bin/rustc
Accessing: /Users/r/.cargo/bin/cargo
Accessing: /opt/homebrew/bin/git
Accessing: /usr/bin/python3
```

### Common False Positives

These are usually acceptable:
- `/etc/localtime`, `/etc/passwd` - System configuration
- `/System/Library/` (macOS), `/lib/`, `/usr/lib/` - System libraries
- `/dev/null`, `/dev/urandom` - Device files

## What to Look For

**Red flags indicating non-hermetic behavior:**

1. **System Tool Usage:**
   - `/usr/bin/git`, `/usr/bin/cargo`, `/usr/bin/rustc`
   - Should use hermetic toolchains from `external/`

2. **User-Specific Paths:**
   - `$HOME/.cargo/`, `$HOME/.rustup/`
   - `$HOME/go/`, `$HOME/.npm/`
   - Should not access user installations

3. **Package Manager Paths:**
   - `/usr/local/bin/` (Homebrew)
   - `/opt/homebrew/` (Homebrew on Apple Silicon)
   - Should use Bazel-managed tools

4. **Network Access During Build:**
   - HTTP/HTTPS requests (except repository_rule phase)
   - Git operations (should be in repository setup only)

## Integration with CI

Add to your CI pipeline:

```yaml
# .github/workflows/hermetic_test.yml
name: Hermiticity Test
on: [pull_request]

jobs:
  test_hermetic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install strace
        run: sudo apt-get install -y strace
      - name: Test hermiticity
        run: |
          ./tools/hermetic_test/linux_hermetic_test.sh //examples/rust_hello:rust_hello_component
```

## Troubleshooting

### "Permission denied" on macOS
```bash
# fs_usage requires root
sudo ./tools/hermetic_test/macos_hermetic_test.sh <target>
```

### "strace not found" on Linux
```bash
# Install strace
sudo apt-get install strace  # Debian/Ubuntu
sudo dnf install strace       # Fedora/RHEL
```

### Too many false positives
Use the Bazel execution log approach instead:
```bash
bazel build --execution_log_json_file=/tmp/exec.log <target>
python3 tools/hermetic_test/analyze_exec_log.py /tmp/exec.log
```

## Future Improvements

- [ ] Bazel test rule for hermiticity checking
- [ ] Windows support using Process Monitor
- [ ] Automated CI integration
- [ ] Dashboard for tracking hermiticity metrics
