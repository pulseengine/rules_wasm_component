package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Config represents the JSON configuration for file operations
type Config struct {
	WorkspaceDir string      `json:"workspace_dir"`
	Operations   []Operation `json:"operations"`
}

// Operation represents a single file operation
type Operation struct {
	Type       string   `json:"type"`
	SrcPath    string   `json:"src_path,omitempty"`
	DestPath   string   `json:"dest_path,omitempty"`
	Path       string   `json:"path,omitempty"`
	Command    string   `json:"command,omitempty"`
	Args       []string `json:"args,omitempty"`
	WorkDir    string   `json:"work_dir,omitempty"`
	OutputFile string   `json:"output_file,omitempty"`
}

// FileOpsRunner executes file operations hermetically
type FileOpsRunner struct {
	config Config
}

// NewFileOpsRunner creates a new file operations runner
func NewFileOpsRunner(configPath string) (*FileOpsRunner, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config JSON: %w", err)
	}

	return &FileOpsRunner{config: config}, nil
}

// Execute runs all file operations
func (r *FileOpsRunner) Execute() error {
	// Create workspace directory first
	if err := os.MkdirAll(r.config.WorkspaceDir, 0755); err != nil {
		return fmt.Errorf("failed to create workspace directory %s: %w", r.config.WorkspaceDir, err)
	}

	log.Printf("Created workspace directory: %s", r.config.WorkspaceDir)

	// Execute operations in order
	for i, op := range r.config.Operations {
		if err := r.executeOperation(op); err != nil {
			return fmt.Errorf("operation %d failed: %w", i, err)
		}
	}

	log.Printf("Successfully completed %d operations", len(r.config.Operations))
	return nil
}

// executeOperation executes a single operation
func (r *FileOpsRunner) executeOperation(op Operation) error {
	switch op.Type {
	case "copy_file":
		return r.copyFile(op.SrcPath, op.DestPath)
	case "mkdir":
		return r.createDirectory(op.Path)
	case "copy_directory_contents":
		return r.copyDirectoryContents(op.SrcPath, op.DestPath)
	case "run_command":
		return r.runCommand(op.Command, op.Args, op.WorkDir, op.OutputFile)
	default:
		return fmt.Errorf("unknown operation type: %s", op.Type)
	}
}

// copyFile copies a file from src to dest within the workspace
func (r *FileOpsRunner) copyFile(srcPath, destPath string) error {
	// Destination is relative to workspace
	fullDestPath := filepath.Join(r.config.WorkspaceDir, destPath)

	// Ensure destination directory exists
	destDir := filepath.Dir(fullDestPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create destination directory %s: %w", destDir, err)
	}

	// Open source file
	srcFile, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("failed to open source file %s: %w", srcPath, err)
	}
	defer srcFile.Close()

	// Create destination file
	destFile, err := os.Create(fullDestPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file %s: %w", fullDestPath, err)
	}
	defer destFile.Close()

	// Copy file contents
	_, err = io.Copy(destFile, srcFile)
	if err != nil {
		return fmt.Errorf("failed to copy file contents: %w", err)
	}

	log.Printf("Copied: %s -> %s", srcPath, destPath)
	return nil
}

// createDirectory creates a directory within the workspace
func (r *FileOpsRunner) createDirectory(path string) error {
	fullPath := filepath.Join(r.config.WorkspaceDir, path)
	if err := os.MkdirAll(fullPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", fullPath, err)
	}
	log.Printf("Created directory: %s", path)
	return nil
}

// copyDirectoryContents copies all contents of a directory to destination
func (r *FileOpsRunner) copyDirectoryContents(srcPath, destPath string) error {
	// Destination is relative to workspace
	fullDestPath := filepath.Join(r.config.WorkspaceDir, destPath)

	// Ensure destination directory exists
	if err := os.MkdirAll(fullDestPath, 0755); err != nil {
		return fmt.Errorf("failed to create destination directory %s: %w", fullDestPath, err)
	}

	// Open source directory
	srcDir, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("failed to open source directory %s: %w", srcPath, err)
	}
	defer srcDir.Close()

	// Read directory entries
	entries, err := srcDir.Readdir(-1)
	if err != nil {
		return fmt.Errorf("failed to read directory entries: %w", err)
	}

	// Copy each entry
	for _, entry := range entries {
		srcEntryPath := filepath.Join(srcPath, entry.Name())
		destEntryPath := filepath.Join(fullDestPath, entry.Name())

		if entry.IsDir() {
			// Recursively copy directory
			if err := r.copyDirectoryRecursive(srcEntryPath, destEntryPath); err != nil {
				return fmt.Errorf("failed to copy directory %s: %w", entry.Name(), err)
			}
		} else {
			// Copy file
			if err := r.copyFileToAbsolute(srcEntryPath, destEntryPath); err != nil {
				return fmt.Errorf("failed to copy file %s: %w", entry.Name(), err)
			}
		}
	}

	log.Printf("Copied directory contents: %s -> %s", srcPath, destPath)
	return nil
}

// copyDirectoryRecursive recursively copies a directory
func (r *FileOpsRunner) copyDirectoryRecursive(srcPath, destPath string) error {
	if err := os.MkdirAll(destPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", destPath, err)
	}

	srcDir, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("failed to open source directory %s: %w", srcPath, err)
	}
	defer srcDir.Close()

	entries, err := srcDir.Readdir(-1)
	if err != nil {
		return fmt.Errorf("failed to read directory entries: %w", err)
	}

	for _, entry := range entries {
		srcEntryPath := filepath.Join(srcPath, entry.Name())
		destEntryPath := filepath.Join(destPath, entry.Name())

		if entry.IsDir() {
			if err := r.copyDirectoryRecursive(srcEntryPath, destEntryPath); err != nil {
				return err
			}
		} else {
			if err := r.copyFileToAbsolute(srcEntryPath, destEntryPath); err != nil {
				return err
			}
		}
	}

	return nil
}

// copyFileToAbsolute copies a file to an absolute destination path
func (r *FileOpsRunner) copyFileToAbsolute(srcPath, destPath string) error {
	srcFile, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("failed to open source file %s: %w", srcPath, err)
	}
	defer srcFile.Close()

	destFile, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file %s: %w", destPath, err)
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, srcFile)
	if err != nil {
		return fmt.Errorf("failed to copy file contents: %w", err)
	}

	return nil
}

// runCommand executes a command in the specified working directory
func (r *FileOpsRunner) runCommand(command string, args []string, workDir, outputFile string) error {
	// Set working directory - relative to workspace if specified
	var fullWorkDir string
	if workDir != "" {
		if filepath.IsAbs(workDir) {
			fullWorkDir = workDir
		} else {
			fullWorkDir = filepath.Join(r.config.WorkspaceDir, workDir)
		}
	} else {
		fullWorkDir = r.config.WorkspaceDir
	}

	// Create command
	cmd := exec.Command(command, args...)
	cmd.Dir = fullWorkDir

	// Handle output
	if outputFile != "" {
		// Output to file (relative to workspace)
		var fullOutputPath string
		if filepath.IsAbs(outputFile) {
			fullOutputPath = outputFile
		} else {
			fullOutputPath = filepath.Join(r.config.WorkspaceDir, outputFile)
		}

		// Ensure output directory exists
		outDir := filepath.Dir(fullOutputPath)
		if err := os.MkdirAll(outDir, 0755); err != nil {
			return fmt.Errorf("failed to create output directory %s: %w", outDir, err)
		}

		outFile, err := os.Create(fullOutputPath)
		if err != nil {
			return fmt.Errorf("failed to create output file %s: %w", fullOutputPath, err)
		}
		defer outFile.Close()

		cmd.Stdout = outFile
		cmd.Stderr = os.Stderr
	} else {
		// Output to logs
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}

	log.Printf("Running command: %s %v in %s", command, args, fullWorkDir)

	// Execute command
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("command failed: %w", err)
	}

	log.Printf("Command completed successfully")
	return nil
}

// validateConfig performs basic validation on the configuration
func (r *FileOpsRunner) validateConfig() error {
	if r.config.WorkspaceDir == "" {
		return fmt.Errorf("workspace_dir cannot be empty")
	}

	// Note: In Bazel sandbox, paths may be relative to execution root
	// Bazel handles path resolution, so we don't strictly require absolute paths

	for i, op := range r.config.Operations {
		switch op.Type {
		case "copy_file":
			if op.SrcPath == "" || op.DestPath == "" {
				return fmt.Errorf("operation %d: copy_file requires src_path and dest_path", i)
			}
			// Note: src_path can be Bazel-relative (e.g., bazel-out/...)
			// dest_path should be relative to workspace
			if filepath.IsAbs(op.DestPath) {
				return fmt.Errorf("operation %d: dest_path must be relative: %s", i, op.DestPath)
			}
		case "mkdir":
			if op.Path == "" {
				return fmt.Errorf("operation %d: mkdir requires path", i)
			}
			if filepath.IsAbs(op.Path) {
				return fmt.Errorf("operation %d: mkdir path must be relative: %s", i, op.Path)
			}
		case "copy_directory_contents":
			if op.SrcPath == "" || op.DestPath == "" {
				return fmt.Errorf("operation %d: copy_directory_contents requires src_path and dest_path", i)
			}
			// Note: src_path can be Bazel-relative (e.g., bazel-out/...)
			// dest_path should be relative to workspace
			if filepath.IsAbs(op.DestPath) {
				return fmt.Errorf("operation %d: dest_path must be relative: %s", i, op.DestPath)
			}
		case "run_command":
			if op.Command == "" {
				return fmt.Errorf("operation %d: run_command requires command", i)
			}
		default:
			return fmt.Errorf("operation %d: unknown operation type: %s", i, op.Type)
		}
	}

	return nil
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <config.json>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nHermetic file operations tool for Bazel rules_wasm_component\n")
		fmt.Fprintf(os.Stderr, "Reads JSON configuration and executes file operations safely.\n")
		os.Exit(1)
	}

	configPath := os.Args[1]

	// Create and validate runner
	runner, err := NewFileOpsRunner(configPath)
	if err != nil {
		log.Fatalf("Failed to create file operations runner: %v", err)
	}

	if err := runner.validateConfig(); err != nil {
		log.Fatalf("Invalid configuration: %v", err)
	}

	// Execute operations
	if err := runner.Execute(); err != nil {
		log.Fatalf("File operations failed: %v", err)
	}

	// Check for any path traversal attempts (security)
	for _, op := range runner.config.Operations {
		if op.Type == "copy_file" && containsPathTraversal(op.DestPath) {
			log.Fatalf("Security violation: path traversal detected in %s", op.DestPath)
		}
		if op.Type == "mkdir" && containsPathTraversal(op.Path) {
			log.Fatalf("Security violation: path traversal detected in %s", op.Path)
		}
	}

	log.Printf("File operations completed successfully")
}

// containsPathTraversal checks for path traversal attempts
func containsPathTraversal(path string) bool {
	cleaned := filepath.Clean(path)
	return strings.Contains(cleaned, "..") || strings.HasPrefix(cleaned, "/")
}
