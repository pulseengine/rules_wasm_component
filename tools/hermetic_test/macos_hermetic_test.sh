#!/usr/bin/env bash
# Hermiticity test using fs_usage on macOS
# This script is intentionally a shell script as it's a testing/diagnostic tool,
# not part of the build system itself.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORKSPACE_DIR="$(pwd)"

# Paths that are ALLOWED (hermetic)
ALLOWED_PATTERNS=(
    "$WORKSPACE_DIR/bazel-"          # Bazel workspace directories
    "$WORKSPACE_DIR/external/"       # External dependencies
    "/private/tmp/"                  # Temporary files
    "/tmp/"                          # Temporary files
    "/dev/"                          # Device files (normal)
    "/System/Library/"               # System libraries (normal)
    "/usr/lib/"                      # System libraries (acceptable)
    "/Library/Developer/CommandLineTools/" # Xcode tools (acceptable)
    "/private/var/tmp/_bazel"        # Bazel cache
)

# Paths that are SUSPICIOUS (potentially non-hermetic)
SUSPICIOUS_PATTERNS=(
    "/usr/local/bin/"                # Homebrew binaries
    "/usr/local/Cellar/"             # Homebrew packages
    "/opt/homebrew/"                 # Homebrew on Apple Silicon
    "$HOME/.cargo"                   # User Rust installation
    "$HOME/.rustup"                  # User Rust toolchain
    "$HOME/go"                       # User Go installation
    "$HOME/.cache"                   # User caches
    "/usr/bin/git"                   # System git (should use hermetic)
    "/usr/bin/python"                # System python
    "/usr/bin/cargo"                 # System cargo
    "/usr/bin/rustc"                 # System rustc
)

# Files/patterns to ignore (known acceptable access)
IGNORE_PATTERNS=(
    "/etc/"
    "/var/db/"
    ".dylib"
    ".tbd"
    "/usr/share/"
    "CFPreferences"
    "com.apple."
)

echo "🔍 Testing Bazel build hermeticity on macOS..."
echo ""
echo -e "${YELLOW}⚠️  This requires sudo access to run fs_usage${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Build target to test
TARGET="${1:-//examples/rust_hello:rust_hello_component}"
FS_USAGE_LOG="/tmp/bazel_fs_usage_$$.log"

echo "Target: $TARGET"
echo "fs_usage log: $FS_USAGE_LOG"
echo "Workspace: $WORKSPACE_DIR"
echo ""

# Clean to ensure fresh build
echo "🧹 Cleaning Bazel cache..."
sudo -u "$SUDO_USER" bazel clean

echo ""
echo "🔨 Starting build with fs_usage monitoring..."
echo -e "${BLUE}(This will take a moment...)${NC}"
echo ""

# Start fs_usage in background, filtering for bazel processes
fs_usage -w -f filesystem | grep -i bazel > "$FS_USAGE_LOG" &
FS_USAGE_PID=$!

# Give fs_usage a moment to start
sleep 2

# Run the build
sudo -u "$SUDO_USER" bazel build "$TARGET" > /dev/null 2>&1

# Give fs_usage time to catch up
sleep 2

# Stop fs_usage
kill $FS_USAGE_PID 2>/dev/null || true

echo "📊 Analyzing filesystem access..."
echo ""

# Analyze the log
suspicious_count=0
declare -A suspicious_files

while IFS= read -r line; do
    # Extract file paths from fs_usage output
    # fs_usage format: syscall  time  process(pid)  file

    # Skip if line doesn't contain a path
    if [[ ! "$line" =~ [[:space:]]/ ]]; then
        continue
    fi

    # Extract the rightmost path (fs_usage puts it at the end)
    filepath=$(echo "$line" | grep -o '/[^ ]*' | tail -1)

    if [ -z "$filepath" ]; then
        continue
    fi

    # Check if it should be ignored
    ignore=false
    for ignore_pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$filepath" == *"$ignore_pattern"* ]]; then
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
done < "$FS_USAGE_LOG"

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
    echo "Review the full log: $FS_USAGE_LOG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Keep the log file for analysis
echo ""
echo "Full fs_usage log saved to: $FS_USAGE_LOG"
echo "To analyze manually: cat $FS_USAGE_LOG | less"

exit ${#suspicious_files[@]}
