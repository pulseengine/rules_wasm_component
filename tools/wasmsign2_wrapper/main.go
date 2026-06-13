package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Wrapper for wasmsign2 WASM component
// Resolves symlinks to real paths and calls wasmtime with limited directory access
func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: wasmsign2_wrapper <command> [args...]")
	}

	// Internal-only Bazel coordination flags. These never reach wsc.
	//   --bazel-wasmtime=PATH          Path to the wasmtime binary to exec.
	//   --bazel-wasm-component=PATH    Path to the wasmsign2 WASM component.
	//   --bazel-marker-file=PATH       Write "Verification passed\n" on success.
	//   --bazel-stage-source=PATH      Copy PATH to the --output-file location
	//                                  before running wsc. Lets rules pass the
	//                                  post-transformation WASM as a separate
	//                                  input and have the wrapper stage it so
	//                                  wsc can read-modify-write the output.
	//   --bazel-capture-stdout=PATH    Write wsc's stdout to PATH instead of
	//                                  inheriting this process's stdout. Used
	//                                  by show-chain to produce a Bazel output
	//                                  artifact.
	//
	// wasmtime and the wasm component are passed by the calling rule (and staged
	// as action inputs) rather than located via runfiles: a hardcoded runfiles
	// Rlocation embeds the canonical repo name, which differs when
	// rules_wasm_component is consumed as a dependency (it gains a
	// `rules_wasm_component+` prefix), breaking downstream signing (issue #501,
	// same fix as #490/#497). wasmtime opens both files natively.
	var markerFile string
	var stageSource string
	var captureStdout string
	var wasmtimeBinary string
	var wasmsign2Wasm string
	filteredArgs := make([]string, 0, len(os.Args))
	for i, arg := range os.Args {
		switch {
		case strings.HasPrefix(arg, "--bazel-wasmtime="):
			wasmtimeBinary = strings.TrimPrefix(arg, "--bazel-wasmtime=")
		case strings.HasPrefix(arg, "--bazel-wasm-component="):
			wasmsign2Wasm = strings.TrimPrefix(arg, "--bazel-wasm-component=")
		case strings.HasPrefix(arg, "--bazel-marker-file="):
			markerFile = strings.TrimPrefix(arg, "--bazel-marker-file=")
		case strings.HasPrefix(arg, "--bazel-stage-source="):
			stageSource = strings.TrimPrefix(arg, "--bazel-stage-source=")
		case strings.HasPrefix(arg, "--bazel-capture-stdout="):
			captureStdout = strings.TrimPrefix(arg, "--bazel-capture-stdout=")
		default:
			if i > 0 { // Skip program name
				filteredArgs = append(filteredArgs, arg)
			}
		}
	}

	if wasmtimeBinary == "" {
		log.Fatal("Missing required --bazel-wasmtime=PATH")
	}
	if wasmsign2Wasm == "" {
		log.Fatal("Missing required --bazel-wasm-component=PATH")
	}
	if _, err := os.Stat(wasmtimeBinary); err != nil {
		log.Fatalf("Wasmtime binary not found at %s: %v", wasmtimeBinary, err)
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

	// Stage the post-transformation WASM into the declared Bazel output before
	// invoking wsc, which reads and rewrites --output-file in place.
	if stageSource != "" {
		outPath := findFlagValue(resolvedArgs, "--output-file", "-o")
		if outPath == "" {
			log.Fatal("--bazel-stage-source requires a resolvable --output-file or -o in the wsc command")
		}
		data, readErr := os.ReadFile(stageSource)
		if readErr != nil {
			log.Fatalf("Failed to read stage source %s: %v", stageSource, readErr)
		}
		if writeErr := os.WriteFile(outPath, data, 0644); writeErr != nil {
			log.Fatalf("Failed to stage %s -> %s: %v", stageSource, outPath, writeErr)
		}
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
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if captureStdout != "" {
		outFile, createErr := os.Create(captureStdout)
		if createErr != nil {
			log.Fatalf("Failed to create stdout capture file %s: %v", captureStdout, createErr)
		}
		defer outFile.Close()
		cmd.Stdout = outFile
	} else {
		cmd.Stdout = os.Stdout
	}

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

	// Track which flags expect file paths.
	// Covers sign/verify/keygen (legacy) plus attest/verify-chain/show-chain
	// (wsc 0.7.0+ attestation commands).
	pathFlags := map[string]bool{
		"-i": true, "--input":       true,
		"-o": true, "--output":      true,
		"-k": true, "--secret-key":  true,
		"-K": true, "--public-key":  true,
		"-S": true, "--signature":   true,
		"--public-key-name":  true,
		"--secret-key-name":  true,
		"--input-file":       true,
		"--output-file":      true,
		"-p": true, "--policy": true,
		"--trusted-tools": true,
		"--audit-file":    true,
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
			strings.HasPrefix(arg, "-S=") ||
			strings.HasPrefix(arg, "--input-file=") ||
			strings.HasPrefix(arg, "--output-file=") ||
			strings.HasPrefix(arg, "-p=") || strings.HasPrefix(arg, "--policy=") ||
			strings.HasPrefix(arg, "--trusted-tools=") ||
			strings.HasPrefix(arg, "--audit-file=")) {
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

// findFlagValue returns the value of a long or short flag in the resolved
// arg list, supporting both "--flag val" and "--flag=val" forms. Returns ""
// if neither form is present.
func findFlagValue(args []string, longFlag, shortFlag string) string {
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == longFlag || (shortFlag != "" && a == shortFlag) {
			if i+1 < len(args) {
				return args[i+1]
			}
			return ""
		}
		if strings.HasPrefix(a, longFlag+"=") {
			return strings.TrimPrefix(a, longFlag+"=")
		}
		if shortFlag != "" && strings.HasPrefix(a, shortFlag+"=") {
			return strings.TrimPrefix(a, shortFlag+"=")
		}
	}
	return ""
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
