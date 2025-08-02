package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	var (
		outputDir   = flag.String("output-dir", "", "Output directory for WAC deps")
		manifest    = flag.String("manifest", "", "Component manifest content")
		profileInfo = flag.String("profile-info", "", "Profile info content")
		useSymlinks = flag.Bool("use-symlinks", true, "Use symlinks instead of copying")
	)
	flag.Parse()

	if *outputDir == "" {
		fmt.Fprintf(os.Stderr, "Error: --output-dir is required\n")
		os.Exit(1)
	}

	// Parse component arguments
	components := make(map[string]string)
	for _, arg := range flag.Args() {
		if strings.HasPrefix(arg, "--component=") {
			parts := strings.SplitN(arg[12:], "=", 2)
			if len(parts) == 2 {
				components[parts[0]] = parts[1]
			}
		}
	}

	// Create output directory
	if err := os.MkdirAll(*outputDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating output directory: %v\n", err)
		os.Exit(1)
	}

	// Create component files
	for name, path := range components {
		destPath := filepath.Join(*outputDir, name+".wasm")

		if *useSymlinks {
			// Create relative symlink
			relPath, err := filepath.Rel(filepath.Dir(destPath), path)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error computing relative path for %s: %v\n", name, err)
				os.Exit(1)
			}
			if err := os.Symlink(relPath, destPath); err != nil {
				fmt.Fprintf(os.Stderr, "Error creating symlink for %s: %v\n", name, err)
				os.Exit(1)
			}
		} else {
			// Copy file
			if err := copyFile(path, destPath); err != nil {
				fmt.Fprintf(os.Stderr, "Error copying file for %s: %v\n", name, err)
				os.Exit(1)
			}
		}
	}

	// Create manifest file
	if *manifest != "" {
		manifestPath := filepath.Join(*outputDir, "components.toml")
		if err := os.WriteFile(manifestPath, []byte(*manifest), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing manifest: %v\n", err)
			os.Exit(1)
		}
	}

	// Create profile info file
	if *profileInfo != "" {
		profilePath := filepath.Join(*outputDir, "profile_info.txt")
		if err := os.WriteFile(profilePath, []byte(*profileInfo), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing profile info: %v\n", err)
			os.Exit(1)
		}
	}
}

func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return err
	}

	return destFile.Sync()
}
