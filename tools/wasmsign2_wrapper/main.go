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

// Wrapper for wasmsign2 WASM component
// Resolves symlinks to real paths and calls wasmtime with limited directory access
func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: wasmsign2_wrapper <command> [args...]")
	}

	// Check for --bazel-marker-file flag (internal use only)
	var markerFile string
	filteredArgs := make([]string, 0, len(os.Args))
	for i, arg := range os.Args {
		if strings.HasPrefix(arg, "--bazel-marker-file=") {
			markerFile = strings.TrimPrefix(arg, "--bazel-marker-file=")
		} else if i > 0 { // Skip program name
			filteredArgs = append(filteredArgs, arg)
		}
	}

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

	// Locate wasmsign2 WASM component
	wasmsign2Wasm, err := r.Rlocation("+_repo_rules+wasmsign2_cli_wasm/file/wasmsign2.wasm")
	if err != nil {
		log.Fatalf("Failed to locate wasmsign2.wasm: %v", err)
	}

	if _, err := os.Stat(wasmsign2Wasm); err != nil {
		log.Fatalf("wasmsign2.wasm not found at %s: %v", wasmsign2Wasm, err)
	}

	// Parse command
	command := filteredArgs[0]
	cmdArgs := filteredArgs[1:]

	// Resolve all file paths in arguments to real paths
	resolvedArgs, dirs, err := resolvePathsInArgs(command, cmdArgs)
	if err != nil {
		log.Fatalf("Failed to resolve paths: %v", err)
	}

	// Build wasmtime command with directory mappings
	wasmtimeArgs := []string{
		"run",
		"-S", "cli",
		"-S", "http",
	}

	// Add unique directory mappings
	uniqueDirs := uniqueStrings(dirs)
	for _, dir := range uniqueDirs {
		wasmtimeArgs = append(wasmtimeArgs, "--dir", dir)
	}

	// Add wasmsign2.wasm and command with resolved arguments
	wasmtimeArgs = append(wasmtimeArgs, wasmsign2Wasm, command)
	wasmtimeArgs = append(wasmtimeArgs, resolvedArgs...)

	// Execute wasmtime
	cmd := exec.Command(wasmtimeBinary, wasmtimeArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		log.Fatalf("Failed to execute wasmtime: %v", err)
	}

	// If marker file was requested, create it on success
	if markerFile != "" {
		if err := os.WriteFile(markerFile, []byte("Verification passed\n"), 0644); err != nil {
			log.Fatalf("Failed to write marker file: %v", err)
		}
	}
}

// resolvePathsInArgs resolves file paths in command arguments
// Returns resolved arguments and list of directories to map
func resolvePathsInArgs(command string, args []string) ([]string, []string, error) {
	resolvedArgs := make([]string, 0, len(args))
	dirs := make([]string, 0)

	// Track which flags expect file paths
	pathFlags := map[string]bool{
		"-i": true, "--input":       true,
		"-o": true, "--output":      true,
		"-k": true, "--secret-key":  true,
		"-K": true, "--public-key":  true,
		"-S": true, "--signature":   true,
		"--public-key-name":  true,
		"--secret-key-name":  true,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]

		// Check if this is a flag that expects a path
		if pathFlags[arg] && i+1 < len(args) {
			// Next argument is a file path
			resolvedArgs = append(resolvedArgs, arg)
			i++
			path := args[i]

			// Resolve to real path
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
		} else if strings.Contains(arg, "=") && (strings.HasPrefix(arg, "--public-key-name=") ||
			strings.HasPrefix(arg, "--secret-key-name=") ||
			strings.HasPrefix(arg, "-i=") || strings.HasPrefix(arg, "-o=") ||
			strings.HasPrefix(arg, "-k=") || strings.HasPrefix(arg, "-K=") ||
			strings.HasPrefix(arg, "-S=")) {
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
