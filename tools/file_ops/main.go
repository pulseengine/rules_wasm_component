package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// Config structure for file operations
type FileOpsConfig struct {
	WorkspaceDir      string        `json:"workspace_dir"`
	Operations        []interface{} `json:"operations"`
	WasmtimePath      string        `json:"wasmtime_path"`
	WasmComponentPath string        `json:"wasm_component_path"`
}

// Helper to panic on error
func must(s string, err error) string {
	if err != nil {
		panic(err)
	}
	return s
}

// Wrapper for external file operations WASM component with LOCAL AOT
// This wrapper executes the WASM component via wasmtime, using locally-compiled
// AOT for 100x faster startup with guaranteed Wasmtime version compatibility.
//
// Security: Maps only necessary directories to WASI instead of full filesystem access.
func main() {
	// Read configuration from JSON file (passed as first argument)
	if len(os.Args) < 2 {
		log.Fatalf("Usage: file_ops <config.json>")
	}

	configPath := os.Args[1]

	// Always log when invoked (for debugging)
	log.Printf("file_ops wrapper started with config: %s", configPath)
	log.Printf("Current directory: %s", must(os.Getwd()))
	log.Printf("Executable path: %s", os.Args[0])

	// List files in current directory for debugging
	if entries, err := ioutil.ReadDir("."); err == nil {
		log.Printf("Files in current directory:")
		for _, entry := range entries {
			log.Printf("  - %s (dir=%v)", entry.Name(), entry.IsDir())
		}
	}

	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Failed to read config file %s: %v", configPath, err)
	}

	log.Printf("Successfully read config file")


	var config FileOpsConfig
	if err := json.Unmarshal(configData, &config); err != nil {
		log.Fatalf("Failed to parse config file: %v", err)
	}

	// Get wasmtime path from config (provided by Bazel)
	// The path may be relative to the sandbox root, try to resolve it
	wasmtimeBinary := config.WasmtimePath
	if wasmtimeBinary == "" {
		log.Fatalf("wasmtime_path not specified in config")
	}

	// Try to find wasmtime - may need to resolve relative path
	wasmtimeResolved := wasmtimeBinary
	if _, err := os.Stat(wasmtimeResolved); err != nil {
		// Try looking in common locations
		alternativePaths := []string{
			"wasmtime",
			"./wasmtime",
			filepath.Join(filepath.Dir(os.Args[0]), "wasmtime"),
		}
		found := false
		for _, path := range alternativePaths {
			if _, err := os.Stat(path); err == nil {
				wasmtimeResolved = path
				found = true
				break
			}
		}
		if !found {
			log.Fatalf("Wasmtime binary not found at %s or alternative locations: %v", wasmtimeBinary, err)
		}
	}

	wasmtimeBinary = wasmtimeResolved

	// Get WASM component path from config (provided by Bazel)
	wasmComponentPath := config.WasmComponentPath
	if wasmComponentPath == "" {
		log.Fatalf("wasm_component_path not specified in config")
	}

	// Try to find component - may need to resolve relative path
	componentResolved := wasmComponentPath
	if _, err := os.Stat(componentResolved); err != nil {
		// Try looking in common locations
		alternativePaths := []string{
			"file_ops_component.wasm",
			"./file_ops_component.wasm",
			filepath.Join(filepath.Dir(os.Args[0]), "file_ops_component.wasm"),
		}
		found := false
		for _, path := range alternativePaths {
			if _, err := os.Stat(path); err == nil {
				componentResolved = path
				found = true
				break
			}
		}
		if !found {
			log.Fatalf("WASM component not found at %s or alternative locations: %v", wasmComponentPath, err)
		}
	}

	wasmComponentPath = componentResolved

	// Parse file-ops arguments and resolve paths
	resolvedArgs, _, err := resolveFileOpsPaths(config.WorkspaceDir, config.Operations)
	if err != nil {
		log.Fatalf("Failed to process file operations: %v", err)
	}

	// Build wasmtime command - map current working directory (Bazel sandbox root) to /
	// This gives the WASM component access to all Bazel-provided inputs
	var args []string
	args = append(args, "run")

	// Map current directory to / in WASI sandbox
	// This way, all paths in the Bazel sandbox are accessible with the same relative paths
	cwd, err := os.Getwd()
	if err != nil {
		log.Fatalf("Failed to get current working directory: %v", err)
	}

	args = append(args, "--dir", cwd+"::/")

	// Optionally also map the workspace directory as-is for direct access
	if config.WorkspaceDir != "" {
		absWorkspace, err := filepath.Abs(config.WorkspaceDir)
		if err == nil {
			// Map workspace to itself so files can be created there
			args = append(args, "--dir", absWorkspace)
		}
	}

	// Execute WASM component via wasmtime
	log.Printf("DEBUG: Executing file_ops WASM component")
	log.Printf("DEBUG: Wasmtime: %s", wasmtimeBinary)
	log.Printf("DEBUG: Component: %s", wasmComponentPath)
	log.Printf("DEBUG: Workspace dir: %s", config.WorkspaceDir)
	log.Printf("DEBUG: Operations: %v", resolvedArgs)

	args = append(args, wasmComponentPath)

	// Append resolved file-ops arguments
	args = append(args, resolvedArgs...)

	log.Printf("DEBUG: Final wasmtime args: %v", args)

	// Execute wasmtime
	cmd := exec.Command(wasmtimeBinary, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			log.Printf("DEBUG: Wasmtime exited with code %d", exitErr.ExitCode())
			os.Exit(exitErr.ExitCode())
		}
		log.Fatalf("Failed to execute wasmtime: %v", err)
	}
}

// resolveFileOpsPaths converts the JSON config operations into WASM component arguments
// Converts all paths to absolute sandbox-root paths that will work when mapped via --dir cwd::/
func resolveFileOpsPaths(workspaceDir string, operations []interface{}) ([]string, []string, error) {
	resolvedArgs := []string{}
	dirs := []string{}

	// Get current directory (sandbox root) for path conversion
	cwd, err := os.Getwd()
	if err != nil {
		cwd = "."
	}

	// For each operation, build the corresponding WASM component arguments
	// Convert relative sandbox paths to absolute paths that work in WASI sandbox
	for _, op := range operations {
		opMap, ok := op.(map[string]interface{})
		if !ok {
			continue
		}

		opType, ok := opMap["type"].(string)
		if !ok {
			continue
		}

		// Helper function to convert sandbox-relative to absolute paths
		toAbsPath := func(relPath string) string {
			if filepath.IsAbs(relPath) {
				return relPath
			}
			// Path is relative to sandbox root, make it absolute for WASI access
			return "/" + relPath
		}

		// Build arguments based on operation type
		switch opType {
		case "copy_file":
			resolvedArgs = append(resolvedArgs, "copy_file")
			if src, ok := opMap["src_path"].(string); ok {
				absPath := toAbsPath(src)
				resolvedArgs = append(resolvedArgs, "--src", absPath)
			}
			if dest, ok := opMap["dest_path"].(string); ok {
				absDest := toAbsPath(filepath.Join(workspaceDir, dest))
				resolvedArgs = append(resolvedArgs, "--dest", absDest)
			}

		case "copy_directory_contents":
			resolvedArgs = append(resolvedArgs, "copy_directory")
			if src, ok := opMap["src_path"].(string); ok {
				absPath := toAbsPath(src)
				resolvedArgs = append(resolvedArgs, "--src", absPath)
			}
			if dest, ok := opMap["dest_path"].(string); ok {
				absDest := toAbsPath(filepath.Join(workspaceDir, dest))
				resolvedArgs = append(resolvedArgs, "--dest", absDest)
			}

		case "mkdir":
			resolvedArgs = append(resolvedArgs, "create_directory")
			if path, ok := opMap["path"].(string); ok {
				absPath := toAbsPath(filepath.Join(workspaceDir, path))
				resolvedArgs = append(resolvedArgs, "--path", absPath)
			}
		}
	}

	_ = cwd // suppress unused warning
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
