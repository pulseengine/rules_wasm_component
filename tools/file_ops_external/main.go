package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// Wrapper for external file operations WASM component with AOT support
// This wrapper executes the pre-built WASM component via wasmtime,
// using extracted AOT artifacts for 100x faster startup
func main() {
	// Initialize Bazel runfiles
	r, err := runfiles.New()
	if err != nil {
		log.Fatalf("Failed to initialize runfiles: %v", err)
	}

	// Locate wasmtime binary using Bazel runfiles
	wasmtimeBinary, err := r.Rlocation("+wasmtime+wasmtime_toolchain/wasmtime")
	if err != nil {
		log.Fatalf("Failed to locate wasmtime: %v", err)
	}

	// Verify wasmtime exists
	if _, err := os.Stat(wasmtimeBinary); err != nil {
		log.Fatalf("Wasmtime binary not found at %s: %v", wasmtimeBinary, err)
	}

	// Determine platform for AOT artifact selection
	osName := runtime.GOOS
	arch := runtime.GOARCH

	// Map Go platform names to AOT artifact names
	platformName := getPlatformName(osName, arch)

	// Try to locate the AOT artifact for this platform
	aotPath, err := r.Rlocation(filepath.Join("_main/tools/file_ops_external", "file_ops_aot_" + platformName + ".cwasm"))
	useAOT := false

	if err == nil {
		if _, err := os.Stat(aotPath); err == nil {
			useAOT = true
		}
	}

	// Build wasmtime command
	var args []string

	if useAOT {
		// Use AOT precompiled artifact for faster startup
		args = []string{
			"run",
			"--dir=/::/", // Preopen root directory for full filesystem access
			"--allow-precompiled",
			aotPath,
		}
	} else {
		// Fall back to regular WASM component
		wasmComponent, err := r.Rlocation("+_repo_rules+file_ops_component_external/file/file_ops_component_aot.wasm")
		if err != nil {
			log.Fatalf("Failed to locate WASM component: %v", err)
		}

		if _, err := os.Stat(wasmComponent); err != nil {
			log.Fatalf("WASM component not found at %s: %v", wasmComponent, err)
		}

		args = []string{
			"run",
			"--dir=/::/",
			wasmComponent,
		}
	}

	// Append all original arguments
	args = append(args, os.Args[1:]...)

	// Execute wasmtime
	cmd := exec.Command(wasmtimeBinary, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		log.Fatalf("Failed to execute wasmtime: %v", err)
	}
}

// getPlatformName maps Go OS/arch to AOT platform names
func getPlatformName(osName, arch string) string {
	switch osName {
	case "linux":
		if arch == "amd64" {
			return "linux_x64"
		} else if arch == "arm64" {
			return "linux_arm64"
		}
	case "darwin":
		if arch == "amd64" {
			return "darwin_x64"
		} else if arch == "arm64" {
			return "darwin_arm64"
		}
	case "windows":
		if arch == "amd64" {
			return "windows_x64"
		}
	}
	return "portable"
}
