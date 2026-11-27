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

// file_ops runs the operations of a JSON config natively in Go. It does not
// run the kapsel (formerly bazel-file-ops-component) wasm. Contract (shared with kapsel's
// JSON-config mode, pulseengine/kapsel#140): one argument,
// the config path; operation types copy_file, mkdir, copy_directory_contents
// and concatenate_files; any other operation is an error (#775).
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

	// Note: wasmtime_path and wasm_component_path are optional - they're only needed
	// if the config uses WASM component execution. File-only operations don't need them.
	// This file_ops wrapper now handles pure file operations directly in Go.

	cwd, err := os.Getwd()
	if err != nil {
		log.Fatalf("Failed to get current working directory: %v", err)
	}

	// Convert workspace_dir to absolute path
	workspaceFullPath := filepath.Join(cwd, config.WorkspaceDir)
	if err := os.MkdirAll(workspaceFullPath, 0755); err != nil {
		log.Fatalf("Failed to create workspace directory: %v", err)
	}

	// Process file operations directly in Go
	log.Printf("DEBUG: Processing %d file operations", len(config.Operations))

	for i, op := range config.Operations {
		opMap, ok := op.(map[string]interface{})
		if !ok {
			log.Fatalf("ERROR: operation %d is not an object", i)
		}

		opType, ok := opMap["type"].(string)
		if !ok {
			log.Fatalf("ERROR: operation %d has no type", i)
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
			walkErr := filepath.Walk(srcDir, func(srcPath string, info os.FileInfo, err error) error {
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
			if walkErr != nil {
				log.Fatalf("ERROR: Failed to copy directory contents from %s to %s: %v", srcDir, destDir, walkErr)
			}
			log.Printf("DEBUG: Copied directory contents from %s to %s", srcDir, destDir)

		case "concatenate_files":
			// Concatenate multiple files into one
			srcPaths, ok := opMap["src_paths"].([]interface{})
			if !ok {
				log.Printf("ERROR: concatenate_files operation missing src_paths")
				os.Exit(1)
			}

			destPath := filepath.Join(workspaceFullPath, opMap["dest_path"].(string))
			os.MkdirAll(filepath.Dir(destPath), 0755)

			// Open destination file for writing
			destFile, err := os.Create(destPath)
			if err != nil {
				log.Printf("ERROR: Failed to create destination file %s: %v", destPath, err)
				os.Exit(1)
			}
			defer destFile.Close()

			// Concatenate each source file
			for _, srcPath := range srcPaths {
				srcPathStr, ok := srcPath.(string)
				if !ok {
					log.Printf("ERROR: Invalid source path in concatenate_files")
					os.Exit(1)
				}

				data, err := ioutil.ReadFile(srcPathStr)
				if err != nil {
					log.Printf("ERROR: Failed to read source file %s: %v", srcPathStr, err)
					os.Exit(1)
				}

				if _, err := destFile.Write(data); err != nil {
					log.Printf("ERROR: Failed to write to destination file %s: %v", destPath, err)
					os.Exit(1)
				}
			}

			log.Printf("DEBUG: Concatenated %d files to %s", len(srcPaths), destPath)

		default:
			log.Fatalf("ERROR: Unknown operation type: %s (supported: copy_file, mkdir, copy_directory_contents, concatenate_files)", opType)
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
