"""Production monitoring and observability for WASM toolchains"""

def log_build_metrics(ctx, tool_name, operation, duration_ms, success):
    """Log build metrics for monitoring"""

    # Create metrics entry
    metrics_entry = {
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "tool": tool_name,
        "operation": operation,
        "duration_ms": duration_ms,
        "success": success,
        "platform": _detect_platform_simple(ctx),
        "bazel_version": "$(bazel version | head -1)",
    }

    # Write to build log for monitoring systems to collect
    print("METRICS: {}".format(str(metrics_entry)))

    return metrics_entry

def _detect_platform_simple(ctx):
    """Simple platform detection for metrics"""
    os_name = ctx.os.name.lower()
    arch = ctx.os.arch.lower()

    # Normalize platform names for cross-platform compatibility
    if "mac" in os_name or "darwin" in os_name:
        os_name = "darwin"
    elif "windows" in os_name:
        os_name = "windows"
    elif "linux" in os_name:
        os_name = "linux"

    # Normalize architecture names
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

def create_health_check(ctx, component_name):
    """Create a health check script for the component"""

    health_check_script = """#!/bin/bash
# Health check for {component}
set -euo pipefail

echo "🏥 Health Check: {component}"
echo "Time: $(date)"
echo "Platform: $(uname -sm)"

# Basic functionality test
if command -v {component} &> /dev/null; then
    echo "✅ {component} executable found"
    {component} --version 2>/dev/null || echo "ℹ️  Version check not supported"
else
    echo "❌ {component} not found in PATH"
    exit 1
fi

echo "✅ Health check passed"
""".format(component = component_name)

    ctx.file("{}_health_check.sh".format(component_name), health_check_script, executable = True)

def add_build_telemetry(ctx, tool_downloads):
    """Add telemetry collection for build metrics"""

    telemetry_script = """#!/bin/bash
# Build telemetry collection
echo "TELEMETRY_START: $(date +%s)"
echo "PLATFORM: $(uname -sm)"
echo "BAZEL_VERSION: $(bazel version 2>/dev/null | head -1 || echo 'unknown')"
echo "TOOL_DOWNLOADS: {}"
echo "TELEMETRY_END: $(date +%s)"
""".format(len(tool_downloads))

    ctx.file("build_telemetry.sh", telemetry_script, executable = True)
