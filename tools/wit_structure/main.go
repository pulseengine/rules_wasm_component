package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
)

type Dependency struct {
	PackageName string   `json:"package_name"`
	SimpleName  string   `json:"simple_name"`
	WitFiles    []string `json:"wit_files"`
}

type Config struct {
	OutputDir        string       `json:"output_dir"`
	SourceFiles      []string     `json:"source_files"`
	Dependencies     []Dependency `json:"dependencies"`
	DepsTomlContent  string       `json:"deps_toml_content"`
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <config.json>\n", os.Args[0])
		os.Exit(1)
	}

	configPath := os.Args[1]
	config, err := readConfig(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading config: %v\n", err)
		os.Exit(1)
	}

	if err := createWitStructure(config); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating WIT structure: %v\n", err)
		os.Exit(1)
	}
}

func readConfig(path string) (*Config, error) {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

func createWitStructure(config *Config) error {
	// Create output directory
	if err := os.MkdirAll(config.OutputDir, 0755); err != nil {
		return fmt.Errorf("creating output directory: %w", err)
	}

	// Copy source files
	for _, srcPath := range config.SourceFiles {
		dstPath := filepath.Join(config.OutputDir, filepath.Base(srcPath))
		if err := copyFile(srcPath, dstPath); err != nil {
			return fmt.Errorf("copying source file %s: %w", srcPath, err)
		}
	}

	// Create deps structure
	if len(config.Dependencies) > 0 {
		depsDir := filepath.Join(config.OutputDir, "deps")
		if err := os.MkdirAll(depsDir, 0755); err != nil {
			return fmt.Errorf("creating deps directory: %w", err)
		}

		for _, dep := range config.Dependencies {
			depDir := filepath.Join(depsDir, dep.SimpleName)
			if err := os.MkdirAll(depDir, 0755); err != nil {
				return fmt.Errorf("creating dependency directory %s: %w", dep.SimpleName, err)
			}

			for _, witFile := range dep.WitFiles {
				dstPath := filepath.Join(depDir, filepath.Base(witFile))
				if err := copyFile(witFile, dstPath); err != nil {
					return fmt.Errorf("copying dependency file %s: %w", witFile, err)
				}
			}
		}
	}

	// Write deps.toml if needed
	if config.DepsTomlContent != "" {
		depsTomlPath := filepath.Join(config.OutputDir, "deps.toml")
		if err := ioutil.WriteFile(depsTomlPath, []byte(config.DepsTomlContent), 0644); err != nil {
			return fmt.Errorf("writing deps.toml: %w", err)
		}
	}

	return nil
}

func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	return err
}