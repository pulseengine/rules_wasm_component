package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type Config struct {
	AnalysisMode    string   `json:"analysis_mode"` // "check" or "suggest"
	WorkspaceDir    string   `json:"workspace_dir"`
	WitFile         string   `json:"wit_file"`
	MissingPackages []string `json:"missing_packages"`
}

type WitPackage struct {
	PackageName string   `json:"package_name"`
	FilePath    string   `json:"file_path"`
	Target      string   `json:"target"`
	Interfaces  []string `json:"interfaces"`
}

type AnalysisResult struct {
	MissingPackages   []string     `json:"missing_packages"`
	AvailablePackages []WitPackage `json:"available_packages"`
	SuggestedDeps     []string     `json:"suggested_deps"`
	ErrorMessage      string       `json:"error_message,omitempty"`
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

	result, err := analyzeWitDependencies(config)
	if err != nil {
		result = &AnalysisResult{
			ErrorMessage: fmt.Sprintf("Analysis failed: %v", err),
		}
	}

	// Output JSON result
	output, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(output))
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

func analyzeWitDependencies(config *Config) (*AnalysisResult, error) {
	result := &AnalysisResult{}

	// Parse the WIT file to find use statements
	missingPackages, err := findMissingPackages(config.WitFile)
	if err != nil {
		return nil, fmt.Errorf("parsing WIT file: %w", err)
	}
	result.MissingPackages = missingPackages

	// If we have missing packages, search the workspace
	if len(missingPackages) > 0 {
		availablePackages, err := findAvailableWitPackages(config.WorkspaceDir)
		if err != nil {
			return nil, fmt.Errorf("searching workspace: %w", err)
		}
		result.AvailablePackages = availablePackages

		// Generate suggestions
		result.SuggestedDeps = generateSuggestions(missingPackages, availablePackages)
	}

	return result, nil
}

func findMissingPackages(witFilePath string) ([]string, error) {
	file, err := os.Open(witFilePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var missingPackages []string
	useRegex := regexp.MustCompile(`use\s+([^/]+)/([^@]+)@([^;]+);`)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if matches := useRegex.FindStringSubmatch(line); matches != nil {
			packageName := matches[1] + "@" + matches[3]
			missingPackages = append(missingPackages, packageName)
		}
	}

	return missingPackages, scanner.Err()
}

func findAvailableWitPackages(workspaceDir string) ([]WitPackage, error) {
	var packages []WitPackage

	err := filepath.Walk(workspaceDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip files we can't read
		}

		// Look for .wit files
		if strings.HasSuffix(path, ".wit") {
			pkg, err := parseWitPackage(path, workspaceDir)
			if err == nil && pkg != nil {
				packages = append(packages, *pkg)
			}
		}

		// Look for BUILD.bazel files to find wit_library targets
		if info.Name() == "BUILD.bazel" || info.Name() == "BUILD" {
			buildPackages, err := parseBuildFile(path, workspaceDir)
			if err == nil {
				packages = append(packages, buildPackages...)
			}
		}

		return nil
	})

	return packages, err
}

func parseWitPackage(filePath, workspaceDir string) (*WitPackage, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	packageRegex := regexp.MustCompile(`package\s+([^;]+);`)
	interfaceRegex := regexp.MustCompile(`interface\s+([^{]+)\s*{`)

	var packageName string
	var interfaces []string

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if matches := packageRegex.FindStringSubmatch(line); matches != nil {
			packageName = strings.TrimSpace(matches[1])
		}

		if matches := interfaceRegex.FindStringSubmatch(line); matches != nil {
			interfaces = append(interfaces, strings.TrimSpace(matches[1]))
		}
	}

	if packageName == "" {
		return nil, fmt.Errorf("no package declaration found")
	}

	relPath, _ := filepath.Rel(workspaceDir, filePath)

	return &WitPackage{
		PackageName: packageName,
		FilePath:    relPath,
		Interfaces:  interfaces,
	}, nil
}

func parseBuildFile(buildPath, workspaceDir string) ([]WitPackage, error) {
	file, err := os.Open(buildPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var packages []WitPackage
	witLibraryRegex := regexp.MustCompile(`wit_library\s*\(\s*name\s*=\s*"([^"]+)"`)
	packageNameRegex := regexp.MustCompile(`package_name\s*=\s*"([^"]+)"`)

	content, err := ioutil.ReadAll(file)
	if err != nil {
		return nil, err
	}

	buildContent := string(content)

	// Find wit_library targets
	witMatches := witLibraryRegex.FindAllStringSubmatch(buildContent, -1)
	packageMatches := packageNameRegex.FindAllStringSubmatch(buildContent, -1)

	for i, witMatch := range witMatches {
		targetName := witMatch[1]
		var packageName string

		// Try to find corresponding package_name
		if i < len(packageMatches) {
			packageName = packageMatches[i][1]
		}

		relPath, _ := filepath.Rel(workspaceDir, buildPath)
		dirPath := filepath.Dir(relPath)

		target := fmt.Sprintf("//%s:%s", dirPath, targetName)

		packages = append(packages, WitPackage{
			PackageName: packageName,
			FilePath:    relPath,
			Target:      target,
		})
	}

	return packages, nil
}

func generateSuggestions(missingPackages []string, availablePackages []WitPackage) []string {
	var suggestions []string

	for _, missing := range missingPackages {
		for _, available := range availablePackages {
			if available.PackageName == missing && available.Target != "" {
				suggestions = append(suggestions, fmt.Sprintf(
					"Add to deps: \"%s\",  # Provides package %s",
					available.Target,
					missing,
				))
			}
		}
	}

	// Sort suggestions for consistent output
	sort.Strings(suggestions)
	return suggestions
}
