package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
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
	Type     string `json:"type"`
	SrcPath  string `json:"src_path,omitempty"`
	DestPath string `json:"dest_path,omitempty"`
	Path     string `json:"path,omitempty"`
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

// validateConfig performs basic validation on the configuration
func (r *FileOpsRunner) validateConfig() error {
	if r.config.WorkspaceDir == "" {
		return fmt.Errorf("workspace_dir cannot be empty")
	}

	if !filepath.IsAbs(r.config.WorkspaceDir) {
		return fmt.Errorf("workspace_dir must be an absolute path: %s", r.config.WorkspaceDir)
	}

	for i, op := range r.config.Operations {
		switch op.Type {
		case "copy_file":
			if op.SrcPath == "" || op.DestPath == "" {
				return fmt.Errorf("operation %d: copy_file requires src_path and dest_path", i)
			}
			if !filepath.IsAbs(op.SrcPath) {
				return fmt.Errorf("operation %d: src_path must be absolute: %s", i, op.SrcPath)
			}
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
