#!/usr/bin/env bash
# Hermiticity test using strace on Linux
# This script is intentionally a shell script as it's a testing/diagnostic tool,
# not part of the build system itself.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

WORKSPACE_DIR="$(pwd)"

# Paths that are ALLOWED (hermetic)
ALLOWED_PATTERNS=(
    "$WORKSPACE_DIR/bazel-"          # Bazel workspace directories
    "$WORKSPACE_DIR/external/"       # External dependencies
    "/tmp/"                          # Temporary files
    "/dev/"                          # Device files (normal)
    "/proc/"                         # Process info (normal)
    "/sys/"                          # System info (normal)
    "/etc/ld.so"                    # Dynamic linker (normal)
    "/lib/"                          # System libraries (acceptable)
    "/lib64/"                        # System libraries (acceptable)
    "/usr/lib/"                      # System libraries (acceptable)
    "$HOME/.cache/bazel"             # Bazel cache
)

# Paths that are SUSPICIOUS (potentially non-hermetic)
SUSPICIOUS_PATTERNS=(
    "/usr/bin/"                      # System tools
    "/usr/local/"                    # User-installed tools
    "$HOME/.cargo"                   # User Rust installation
    "$HOME/.rustup"                  # User Rust toolchain
    "$HOME/go"                       # User Go installation
    "$HOME/.cache/go-build"          # Go build cache
    "$HOME/.npm"                     # npm cache
    "/opt/"                          # Optional software
)

# Files to ignore (known acceptable access)
IGNORE_FILES=(
    "/etc/localtime"
    "/etc/passwd"
    "/etc/group"
    "/etc/hosts"
    "/etc/resolv.conf"
    "/etc/nsswitch.conf"
)

echo "🔍 Testing Bazel build hermeticity with strace..."
echo ""

# Check if strace is available
if ! command -v strace &> /dev/null; then
    echo -e "${RED}ERROR: strace not found. Install with:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install strace"
    echo "  Fedora/RHEL: sudo dnf install strace"
    exit 1
fi

# Build target to test
TARGET="${1:-//examples/rust_hello:rust_hello_component}"
STRACE_LOG="/tmp/bazel_strace_$$.log"

echo "Target: $TARGET"
echo "Strace log: $STRACE_LOG"
echo "Workspace: $WORKSPACE_DIR"
echo ""

# Clean to ensure fresh build
echo "🧹 Cleaning Bazel cache..."
bazel clean

# Run build with strace
echo "🔨 Building with strace..."
strace -f -e trace=open,openat,execve,stat,statfs,access -o "$STRACE_LOG" \
    bazel build "$TARGET" 2>&1 | head -20

echo ""
echo "📊 Analyzing strace output..."
echo ""

# Analyze the log
suspicious_count=0
declare -A suspicious_files

while IFS= read -r line; do
    # Skip lines that don't contain file operations
    if [[ ! "$line" =~ (open|openat|execve|stat|access) ]]; then
        continue
    fi

    # Extract the file path
    if [[ "$line" =~ \"([^\"]+)\" ]]; then
        filepath="${BASH_REMATCH[1]}"

        # Check if it should be ignored
        ignore=false
        for ignore_pattern in "${IGNORE_FILES[@]}"; do
            if [[ "$filepath" == "$ignore_pattern" ]]; then
                ignore=true
                break
            fi
        done

        if $ignore; then
            continue
        fi

        # Check if it's in an allowed path
        allowed=false
        for allowed_pattern in "${ALLOWED_PATTERNS[@]}"; do
            if [[ "$filepath" == "$allowed_pattern"* ]]; then
                allowed=true
                break
            fi
        done

        if $allowed; then
            continue
        fi

        # Check if it's suspicious
        for suspicious_pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
            if [[ "$filepath" == "$suspicious_pattern"* ]]; then
                suspicious_files["$filepath"]=1
                ((suspicious_count++))
                break
            fi
        done
    fi
done < "$STRACE_LOG"

# Report results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    HERMITICITY REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ${#suspicious_files[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ PASSED: No suspicious file access detected!${NC}"
    echo ""
    echo "The build appears to be hermetic."
else
    echo -e "${YELLOW}⚠️  WARNING: Found ${#suspicious_files[@]} suspicious file(s) accessed${NC}"
    echo ""
    echo "Suspicious files accessed:"
    for file in "${!suspicious_files[@]}"; do
        echo -e "  ${RED}•${NC} $file"
    done | sort
    echo ""
    echo "These accesses may indicate non-hermetic behavior."
    echo "Review the full log: $STRACE_LOG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Keep the log file for analysis
echo ""
echo "Full strace log saved to: $STRACE_LOG"
echo "To analyze manually: grep -E '(open|execve)' $STRACE_LOG | less"

exit ${#suspicious_files[@]}
