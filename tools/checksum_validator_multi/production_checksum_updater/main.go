package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Production tool for CI system - downloads and validates checksums for real tools
// This component is used by our Bazel build system to manage tool dependencies

// GitHubRelease represents a GitHub release from API
type GitHubRelease struct {
	TagName     string  `json:"tag_name"`
	Name        string  `json:"name"`
	PublishedAt string  `json:"published_at"`
	Assets      []Asset `json:"assets"`
}

type Asset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
	Size               int64  `json:"size"`
}

// ToolInfo matches our existing JSON structure
type ToolInfo struct {
	ToolName           string                 `json:"tool_name"`
	GitHubRepo         string                 `json:"github_repo"`
	LatestVersion      string                 `json:"latest_version"`
	LastChecked        string                 `json:"last_checked"`
	SupportedPlatforms []string               `json:"supported_platforms"`
	Versions           map[string]VersionInfo `json:"versions"`
}

type VersionInfo struct {
	ReleaseDate string                  `json:"release_date"`
	Platforms   map[string]PlatformInfo `json:"platforms"`
}

type PlatformInfo struct {
	SHA256    string `json:"sha256"`
	URLSuffix string `json:"url_suffix"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Production Checksum Updater for CI System")
		fmt.Println("Usage:")
		fmt.Println("  update-tool <tool-name> <checksums-dir>")
		fmt.Println("  validate-tool <tool-name> <version> <platform> <checksums-dir>")
		fmt.Println("  check-latest <tool-name> <checksums-dir>")
		return
	}

	command := os.Args[1]
	switch command {
	case "update-tool":
		updateTool()
	case "validate-tool":
		validateTool()
	case "check-latest":
		checkLatest()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		os.Exit(1)
	}
}

func updateTool() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: update-tool <tool-name> <checksums-dir>")
		return
	}

	toolName := os.Args[2]
	checksumsDir := os.Args[3]

	fmt.Printf("🔄 Updating checksums for %s\n", toolName)

	// Load existing tool info
	toolPath := filepath.Join(checksumsDir, "tools", toolName+".json")
	toolInfo, err := loadToolInfo(toolPath)
	if err != nil {
		fmt.Printf("❌ Failed to load tool info: %v\n", err)
		os.Exit(1)
	}

	// Fetch latest release from GitHub
	fmt.Printf("📡 Fetching latest release from %s\n", toolInfo.GitHubRepo)
	release, err := fetchLatestRelease(toolInfo.GitHubRepo)
	if err != nil {
		fmt.Printf("❌ Failed to fetch release: %v\n", err)
		os.Exit(1)
	}

	// Check if we already have this version
	if release.TagName == toolInfo.LatestVersion {
		fmt.Printf("✅ Tool %s is already up to date (v%s)\n", toolName, release.TagName)
		return
	}

	fmt.Printf("🆕 New version found: %s → %s\n", toolInfo.LatestVersion, release.TagName)

	// Download and calculate checksums for supported platforms
	newVersionInfo := VersionInfo{
		ReleaseDate: release.PublishedAt[:10], // Extract date part
		Platforms:   make(map[string]PlatformInfo),
	}

	for _, platform := range toolInfo.SupportedPlatforms {
		asset := findAssetForPlatform(release.Assets, platform, toolName)
		if asset == nil {
			fmt.Printf("⚠️  No asset found for platform %s\n", platform)
			continue
		}

		fmt.Printf("📥 Downloading %s for %s...\n", asset.Name, platform)
		sha256Hash, err := downloadAndHash(asset.BrowserDownloadURL)
		if err != nil {
			fmt.Printf("❌ Failed to download %s: %v\n", asset.Name, err)
			continue
		}

		// Extract URL suffix from asset name
		urlSuffix := extractURLSuffix(asset.Name, toolName, release.TagName)

		newVersionInfo.Platforms[platform] = PlatformInfo{
			SHA256:    sha256Hash,
			URLSuffix: urlSuffix,
		}

		fmt.Printf("✅ %s: %s\n", platform, sha256Hash)
	}

	// Update tool info
	toolInfo.LatestVersion = release.TagName
	toolInfo.LastChecked = time.Now().UTC().Format(time.RFC3339)
	toolInfo.Versions[release.TagName] = newVersionInfo

	// Save updated tool info
	err = saveToolInfo(toolPath, toolInfo)
	if err != nil {
		fmt.Printf("❌ Failed to save tool info: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("🎉 Successfully updated %s to version %s\n", toolName, release.TagName)
}

func validateTool() {
	if len(os.Args) < 6 {
		fmt.Println("Usage: validate-tool <tool-name> <version> <platform> <checksums-dir>")
		return
	}

	toolName := os.Args[2]
	version := os.Args[3]
	platform := os.Args[4]
	checksumsDir := os.Args[5]

	fmt.Printf("🔍 Validating %s v%s for %s\n", toolName, version, platform)

	// Load tool info
	toolPath := filepath.Join(checksumsDir, "tools", toolName+".json")
	toolInfo, err := loadToolInfo(toolPath)
	if err != nil {
		fmt.Printf("❌ Failed to load tool info: %v\n", err)
		os.Exit(1)
	}

	// Get expected checksum
	versionInfo, exists := toolInfo.Versions[version]
	if !exists {
		fmt.Printf("❌ Version %s not found for %s\n", version, toolName)
		os.Exit(1)
	}

	platformInfo, exists := versionInfo.Platforms[platform]
	if !exists {
		fmt.Printf("❌ Platform %s not found for %s v%s\n", platform, toolName, version)
		os.Exit(1)
	}

	fmt.Printf("📋 Expected SHA256: %s\n", platformInfo.SHA256)
	fmt.Printf("✅ Checksum validation data available\n")
}

func checkLatest() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: check-latest <tool-name> <checksums-dir>")
		return
	}

	toolName := os.Args[2]
	checksumsDir := os.Args[3]

	// Load tool info
	toolPath := filepath.Join(checksumsDir, "tools", toolName+".json")
	toolInfo, err := loadToolInfo(toolPath)
	if err != nil {
		fmt.Printf("❌ Failed to load tool info: %v\n", err)
		os.Exit(1)
	}

	// Fetch latest release
	release, err := fetchLatestRelease(toolInfo.GitHubRepo)
	if err != nil {
		fmt.Printf("❌ Failed to fetch release: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📦 Current version: %s\n", toolInfo.LatestVersion)
	fmt.Printf("🆕 Latest version: %s\n", release.TagName)

	if release.TagName == toolInfo.LatestVersion {
		fmt.Printf("✅ Tool is up to date\n")
	} else {
		fmt.Printf("🔄 Update available: %s → %s\n", toolInfo.LatestVersion, release.TagName)
	}
}

func loadToolInfo(path string) (*ToolInfo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var toolInfo ToolInfo
	err = json.Unmarshal(data, &toolInfo)
	if err != nil {
		return nil, err
	}

	return &toolInfo, nil
}

func saveToolInfo(path string, toolInfo *ToolInfo) error {
	data, err := json.MarshalIndent(toolInfo, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

func fetchLatestRelease(repo string) (*GitHubRelease, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", repo)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GitHub API error: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var release GitHubRelease
	err = json.Unmarshal(body, &release)
	if err != nil {
		return nil, err
	}

	return &release, nil
}

func findAssetForPlatform(assets []Asset, platform, toolName string) *Asset {
	// Map our platform names to GitHub release patterns
	patterns := map[string][]string{
		"darwin_amd64":  {"macos", "darwin", "x86_64-apple"},
		"darwin_arm64":  {"macos", "darwin", "aarch64-apple", "arm64-apple"},
		"linux_amd64":   {"linux", "x86_64-unknown-linux"},
		"linux_arm64":   {"linux", "aarch64-unknown-linux"},
		"windows_amd64": {"windows", "x86_64-pc-windows"},
	}

	platformPatterns := patterns[platform]
	if platformPatterns == nil {
		return nil
	}

	for _, asset := range assets {
		name := strings.ToLower(asset.Name)

		// Skip source archives
		if strings.Contains(name, "src") || strings.Contains(name, "source") {
			continue
		}

		// Check if asset matches platform patterns
		matchCount := 0
		for _, pattern := range platformPatterns {
			if strings.Contains(name, pattern) {
				matchCount++
			}
		}

		// Require at least one pattern match
		if matchCount > 0 {
			return &asset
		}
	}

	return nil
}

func downloadAndHash(url string) (string, error) {
	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP error: %s", resp.Status)
	}

	hasher := sha256.New()
	_, err = io.Copy(hasher, resp.Body)
	if err != nil {
		return "", err
	}

	return hex.EncodeToString(hasher.Sum(nil)), nil
}

func extractURLSuffix(assetName, toolName, version string) string {
	// Remove version and tool name from asset to get suffix
	suffix := assetName

	// Remove version patterns
	versionPatterns := []string{
		version,
		strings.TrimPrefix(version, "v"),
		toolName + "-" + version,
		toolName + "-" + strings.TrimPrefix(version, "v"),
	}

	for _, pattern := range versionPatterns {
		suffix = strings.ReplaceAll(suffix, pattern, "")
	}

	// Clean up the suffix
	suffix = strings.Trim(suffix, "-_")

	return suffix
}
