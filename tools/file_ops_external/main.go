package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// Wrapper for external file operations WASM component with LOCAL AOT
// This wrapper executes the WASM component via wasmtime, using locally-compiled
// AOT for 100x faster startup with guaranteed Wasmtime version compatibility.
//
// Security: Maps only necessary directories to WASI instead of full filesystem access.
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

	// Parse file-ops arguments and resolve paths
	resolvedArgs, dirs, err := resolveFileOpsPaths(os.Args[1:])
	if err != nil {
		log.Fatalf("Failed to resolve paths: %v", err)
	}

	// Build wasmtime command with limited directory mappings
	var args []string
	args = append(args, "run")

	// Add unique directory mappings (instead of --dir=/::/  for full access)
	uniqueDirs := uniqueStrings(dirs)
	for _, dir := range uniqueDirs {
		args = append(args, "--dir", dir)
	}

	if useAOT {
		// Use locally-compiled AOT - guaranteed compatible with current Wasmtime version
		if os.Getenv("FILE_OPS_DEBUG") != "" {
			log.Printf("DEBUG: Using locally-compiled AOT at %s", aotPath)
			log.Printf("DEBUG: Mapped directories: %v", uniqueDirs)
		}

		args = append(args, "--allow-precompiled", aotPath)
	} else {
		// Fallback to regular WASM (still much faster than embedded Go binary)
		if os.Getenv("FILE_OPS_DEBUG") != "" {
			log.Printf("DEBUG: AOT not available, using regular WASM")
			log.Printf("DEBUG: Mapped directories: %v", uniqueDirs)
		}

		args = append(args, wasmComponent)
	}

	// Append resolved file-ops arguments
	args = append(args, resolvedArgs...)

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

// resolveFileOpsPaths resolves file paths in file-ops arguments
// Returns resolved arguments and list of directories to map
func resolveFileOpsPaths(args []string) ([]string, []string, error) {
	resolvedArgs := make([]string, 0, len(args))
	dirs := make([]string, 0)

	// Flags that expect file/directory paths
	pathFlags := map[string]bool{
		"--src":    true,
		"--dest":   true,
		"--path":   true,
		"--dir":    true,
		"--output": true,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]

		// Check if this is a flag that expects a path
		if pathFlags[arg] && i+1 < len(args) {
			// Next argument is a file path
			resolvedArgs = append(resolvedArgs, arg)
			i++
			path := args[i]

			// Resolve to real path (follows symlinks)
			realPath, err := filepath.EvalSymlinks(path)
			if err != nil {
				// If symlink evaluation fails, try absolute path
				realPath, err = filepath.Abs(path)
				if err != nil {
					return nil, nil, fmt.Errorf("failed to resolve path %s: %w", path, err)
				}
			}

			resolvedArgs = append(resolvedArgs, realPath)

			// Add directory for mapping
			dir := filepath.Dir(realPath)
			dirs = append(dirs, dir)
		} else if strings.Contains(arg, "=") && (strings.HasPrefix(arg, "--src=") ||
			strings.HasPrefix(arg, "--dest=") ||
			strings.HasPrefix(arg, "--path=") ||
			strings.HasPrefix(arg, "--dir=") ||
			strings.HasPrefix(arg, "--output=")) {
			// Handle --flag=value format
			parts := strings.SplitN(arg, "=", 2)
			if len(parts) == 2 {
				flag := parts[0]
				path := parts[1]

				realPath, err := filepath.EvalSymlinks(path)
				if err != nil {
					realPath, err = filepath.Abs(path)
					if err != nil {
						return nil, nil, fmt.Errorf("failed to resolve path %s: %w", path, err)
					}
				}

				resolvedArgs = append(resolvedArgs, flag+"="+realPath)

				dir := filepath.Dir(realPath)
				dirs = append(dirs, dir)
			} else {
				resolvedArgs = append(resolvedArgs, arg)
			}
		} else {
			// Not a path argument, pass through as-is
			resolvedArgs = append(resolvedArgs, arg)
		}
	}

	return resolvedArgs, dirs, nil
}

// uniqueStrings returns unique strings from a slice
func uniqueStrings(strs []string) []string {
	seen := make(map[string]bool)
	result := make([]string, 0, len(strs))

	for _, s := range strs {
		if !seen[s] {
			seen[s] = true
			result = append(result, s)
		}
	}

	return result
}
