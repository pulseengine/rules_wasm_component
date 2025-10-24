package main

import (
	"log"
	"os"
	"os/exec"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// Wrapper for external file operations WASM component with LOCAL AOT
// This wrapper executes the WASM component via wasmtime, using locally-compiled
// AOT for 100x faster startup with guaranteed Wasmtime version compatibility
func main() {
	// Initialize Bazel runfiles
	r, err := runfiles.New()
	if err != nil {
		log.Fatalf("Failed to initialize runfiles: %v", err)
	}

	// Locate wasmtime binary
	wasmtimeBinary, err := r.Rlocation("+wasmtime+wasmtime_toolchain/wasmtime")
	if err != nil {
		log.Fatalf("Failed to locate wasmtime: %v", err)
	}

	if _, err := os.Stat(wasmtimeBinary); err != nil {
		log.Fatalf("Wasmtime binary not found at %s: %v", wasmtimeBinary, err)
	}

	// Try to locate locally-compiled AOT artifact
	// This is compiled at build time with the user's Wasmtime version - guaranteed compatible!
	aotPath, err := r.Rlocation("_main/tools/file_ops_external/file_ops_aot.cwasm")
	useAOT := err == nil

	if useAOT {
		if _, err := os.Stat(aotPath); err != nil {
			useAOT = false
		}
	}

	// Locate regular WASM component for fallback
	wasmComponent, err := r.Rlocation("+_repo_rules+file_ops_component_external/file/file_ops_component.wasm")
	if err != nil {
		log.Fatalf("Failed to locate WASM component: %v", err)
	}

	if _, err := os.Stat(wasmComponent); err != nil {
		log.Fatalf("WASM component not found at %s: %v", wasmComponent, err)
	}

	// Build wasmtime command
	var args []string

	if useAOT {
		// Use locally-compiled AOT - guaranteed compatible with current Wasmtime version
		if os.Getenv("FILE_OPS_DEBUG") != "" {
			log.Printf("DEBUG: Using locally-compiled AOT at %s", aotPath)
		}

		args = []string{
			"run",
			"--dir=/::/", // Preopen root directory for full filesystem access
			"--allow-precompiled",
			aotPath,
		}
	} else {
		// Fallback to regular WASM (still much faster than embedded Go binary)
		if os.Getenv("FILE_OPS_DEBUG") != "" {
			log.Printf("DEBUG: AOT not available, using regular WASM")
		}

		args = []string{
			"run",
			"--dir=/::/",
			wasmComponent,
		}
	}

	// Append original arguments
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
