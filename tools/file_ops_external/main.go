package main

import (
	"log"
	"os"
	"os/exec"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// Wrapper for external file operations WASM component
// This wrapper executes the pre-built WASM component via wasmtime
func main() {
	// Initialize Bazel runfiles
	r, err := runfiles.New()
	if err != nil {
		log.Fatalf("Failed to initialize runfiles: %v", err)
	}

	// Locate WASM component using Bazel runfiles
	wasmComponent, err := r.Rlocation("+_repo_rules+file_ops_component_external/file/file_ops_component.wasm")
	if err != nil {
		log.Fatalf("Failed to locate WASM component: %v", err)
	}

	// Verify the file exists
	if _, err := os.Stat(wasmComponent); err != nil {
		log.Fatalf("WASM component not found at %s: %v", wasmComponent, err)
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

	// Build wasmtime command with proper directory preopens
	// Preopen root directory to allow access to config files and workspaces
	// This matches the embedded Go binary's filesystem access capabilities
	args := []string{
		"run",
		"--dir=/::/", // Preopen root directory for full filesystem access
		wasmComponent,
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
