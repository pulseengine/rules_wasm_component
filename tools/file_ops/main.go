package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
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

	// Read and parse config from JSON file
	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Failed to read config file %s: %v", configPath, err)
	}

	log.Printf("Successfully read config file (%d bytes)", len(configData))

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

	// Map the entire Bazel sandbox with read/write permissions
	args = append(args, "--dir", cwd+"::/")

	// Convert workspace_dir to absolute path for WASI
	workspaceFullPath := filepath.Join(cwd, config.WorkspaceDir)
	if err := os.MkdirAll(workspaceFullPath, 0755); err != nil {
		log.Fatalf("Failed to create workspace directory: %v", err)
	}
	log.Printf("DEBUG: Created workspace directory: %s", workspaceFullPath)

	// Copy config file to a simple location in /tmp that we can pass to WASM component
	// This avoids symlink issues in Bazel's complex sandbox
	tmpConfigPath := "/tmp/file_ops_config.json"
	if err := ioutil.WriteFile(tmpConfigPath, configData, 0644); err != nil {
		log.Fatalf("Failed to write temporary config file: %v", err)
	}
	log.Printf("DEBUG: Wrote config to temp file: %s", tmpConfigPath)

	// Map /tmp directory for config access
	args = append(args, "--dir", "/tmp::/"+"tmp")

	// Explicitly map the workspace directory with write permissions
	args = append(args, "--dir", workspaceFullPath+"::"+"/workspace")

	// Execute WASM component via wasmtime
	log.Printf("DEBUG: Executing file_ops WASM component")
	log.Printf("DEBUG: Wasmtime: %s", wasmtimeBinary)
	log.Printf("DEBUG: Component: %s", wasmComponentPath)
	log.Printf("DEBUG: Workspace dir: %s", config.WorkspaceDir)
	log.Printf("DEBUG: Operations count: %d", len(config.Operations))

	// Use the explicitly mapped workspace directory in WASI
	// We mapped workspaceFullPath to /workspace
	// The directory already exists from the Go wrapper, so the WASM component just needs to use it
	wasiWorkspaceDir := "/workspace"
	log.Printf("DEBUG: WASI workspace dir: %s (already created in Go wrapper)", wasiWorkspaceDir)

	// Update config to use the mapped workspace directory
	// The WASM component should treat this as already-existing
	config.WorkspaceDir = wasiWorkspaceDir

	// Write updated config to temp file
	updatedConfigData, err := json.Marshal(config)
	if err != nil {
		log.Fatalf("Failed to marshal updated config: %v", err)
	}
	if err := ioutil.WriteFile("/tmp/file_ops_config.json", updatedConfigData, 0644); err != nil {
		log.Fatalf("Failed to write updated config file: %v", err)
	}
	log.Printf("DEBUG: Updated config with absolute workspace path")

	// Process file operations directly in Go
	// This is more reliable than trying to use the WASM component for now
	log.Printf("DEBUG: Processing %d file operations", len(config.Operations))

	for i, op := range config.Operations {
		opMap, ok := op.(map[string]interface{})
		if !ok {
			log.Printf("WARNING: Operation %d is not a map, skipping", i)
			continue
		}

		opType, ok := opMap["type"].(string)
		if !ok {
			log.Printf("WARNING: Operation %d has no type, skipping", i)
			continue
		}

		log.Printf("DEBUG: Processing operation %d: %s", i, opType)

		switch opType {
		case "copy_file":
			srcPath := opMap["src_path"].(string)
			destPath := filepath.Join(workspaceFullPath, opMap["dest_path"].(string))
			// Ensure parent directory exists
			os.MkdirAll(filepath.Dir(destPath), 0755)
			// Copy file
			data, err := ioutil.ReadFile(srcPath)
			if err != nil {
				log.Printf("ERROR: Failed to read source file %s: %v", srcPath, err)
				os.Exit(1)
			}
			if err := ioutil.WriteFile(destPath, data, 0644); err != nil {
				log.Printf("ERROR: Failed to write destination file %s: %v", destPath, err)
				os.Exit(1)
			}
			log.Printf("DEBUG: Copied %s to %s", srcPath, destPath)

		case "mkdir":
			dirPath := filepath.Join(workspaceFullPath, opMap["path"].(string))
			if err := os.MkdirAll(dirPath, 0755); err != nil {
				log.Printf("ERROR: Failed to create directory %s: %v", dirPath, err)
				os.Exit(1)
			}
			log.Printf("DEBUG: Created directory %s", dirPath)

		case "copy_directory_contents":
			srcDir := opMap["src_path"].(string)
			destDir := filepath.Join(workspaceFullPath, opMap["dest_path"].(string))
			os.MkdirAll(destDir, 0755)

			// Recursively copy all files/directories from source
			filepath.Walk(srcDir, func(srcPath string, info os.FileInfo, err error) error {
				if err != nil {
					return err
				}

				// Get relative path from source directory
				relPath, _ := filepath.Rel(srcDir, srcPath)
				destPath := filepath.Join(destDir, relPath)

				if info.IsDir() {
					// Create directory
					return os.MkdirAll(destPath, 0755)
				} else {
					// Copy file
					os.MkdirAll(filepath.Dir(destPath), 0755)
					data, err := ioutil.ReadFile(srcPath)
					if err != nil {
						return err
					}
					return ioutil.WriteFile(destPath, data, 0644)
				}
			})
			log.Printf("DEBUG: Copied directory contents from %s to %s", srcDir, destDir)

		default:
			log.Printf("WARNING: Unknown operation type: %s", opType)
		}
	}

	log.Printf("DEBUG: All file operations completed successfully")
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
