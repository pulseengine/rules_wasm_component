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

// GitHubRelease represents a GitHub release
type GitHubRelease struct {
	TagName     string `json:"tag_name"`
	Name        string `json:"name"`
	PublishedAt string `json:"published_at"`
	Assets      []struct {
		Name               string `json:"name"`
		BrowserDownloadURL string `json:"browser_download_url"`
		Size               int64  `json:"size"`
		ContentType        string `json:"content_type"`
	} `json:"assets"`
}

// DownloadResult represents the result of a download operation
type DownloadResult struct {
	URL          string `json:"url"`
	LocalPath    string `json:"local_path"`
	Size         int64  `json:"size"`
	SHA256       string `json:"sha256"`
	DownloadTime int64  `json:"download_time_ms"`
	Success      bool   `json:"success"`
	Error        string `json:"error,omitempty"`
}

// ChecksumValidationRequest represents a validation request
type ChecksumValidationRequest struct {
	FilePath       string `json:"file_path"`
	ExpectedSHA256 string `json:"expected_sha256"`
	ToolName       string `json:"tool_name"`
	Version        string `json:"version"`
	Platform       string `json:"platform"`
}

// ChecksumValidationResult represents validation results
type ChecksumValidationResult struct {
	FilePath      string `json:"file_path"`
	ActualSHA256  string `json:"actual_sha256"`
	ExpectedSHA256 string `json:"expected_sha256"`
	Valid         bool   `json:"valid"`
	FileSize      int64  `json:"file_size"`
	ValidationTime int64  `json:"validation_time_ms"`
	Error         string `json:"error,omitempty"`
}

func main() {
	fmt.Println("🌐 Multi-Language WebAssembly Checksum Validator")
	fmt.Println("=================================================")
	fmt.Println("🔧 Go Component: HTTP Downloader & GitHub API Client")

	if len(os.Args) < 2 {
		showHelp()
		return
	}

	command := os.Args[1]
	switch command {
	case "download":
		handleDownload()
	case "fetch-release-info":
		handleFetchReleaseInfo()
	case "validate-checksum":
		handleValidateChecksum()
	case "download-and-validate":
		handleDownloadAndValidate()
	case "test-connection":
		handleTestConnection()
	default:
		fmt.Printf("❌ Unknown command: %s\n", command)
		showHelp()
	}
}

func showHelp() {
	fmt.Println("Usage:")
	fmt.Println("  download <url> <output-path>")
	fmt.Println("  fetch-release-info <github-repo>")
	fmt.Println("  validate-checksum <file-path> <expected-sha256>")
	fmt.Println("  download-and-validate <url> <output-path> <expected-sha256>")
	fmt.Println("  test-connection")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  download https://github.com/bytecodealliance/wasm-tools/releases/download/v1.0.0/wasm-tools-1.0.0-x86_64-linux.tar.gz ./wasm-tools.tar.gz")
	fmt.Println("  fetch-release-info bytecodealliance/wasm-tools")
	fmt.Println("  validate-checksum ./file.tar.gz abc123...")
	fmt.Println("  test-connection")
}

func handleDownload() {
	if len(os.Args) < 4 {
		fmt.Println("❌ Usage: download <url> <output-path>")
		return
	}

	url := os.Args[2]
	outputPath := os.Args[3]

	result := downloadFile(url, outputPath)
	printDownloadResult(result)
}

func handleFetchReleaseInfo() {
	if len(os.Args) < 3 {
		fmt.Println("❌ Usage: fetch-release-info <github-repo>")
		return
	}

	repo := os.Args[2]
	release, err := fetchLatestRelease(repo)
	if err != nil {
		fmt.Printf("❌ Failed to fetch release info: %v\n", err)
		return
	}

	printReleaseInfo(release)
}

func handleValidateChecksum() {
	if len(os.Args) < 4 {
		fmt.Println("❌ Usage: validate-checksum <file-path> <expected-sha256>")
		return
	}

	filePath := os.Args[2]
	expectedSHA256 := os.Args[3]

	result := validateChecksum(filePath, expectedSHA256)
	printValidationResult(result)
}

func handleDownloadAndValidate() {
	if len(os.Args) < 5 {
		fmt.Println("❌ Usage: download-and-validate <url> <output-path> <expected-sha256>")
		return
	}

	url := os.Args[2]
	outputPath := os.Args[3]
	expectedSHA256 := os.Args[4]

	// Download first
	fmt.Println("📥 Step 1: Downloading file...")
	downloadResult := downloadFile(url, outputPath)
	printDownloadResult(downloadResult)

	if !downloadResult.Success {
		fmt.Println("❌ Download failed, cannot validate checksum")
		return
	}

	// Then validate
	fmt.Println("\n🔍 Step 2: Validating checksum...")
	validationResult := validateChecksum(outputPath, expectedSHA256)
	printValidationResult(validationResult)

	// Summary
	fmt.Println("\n📊 Summary:")
	fmt.Printf("  Downloaded: %s (%d bytes)\n", outputPath, downloadResult.Size)
	fmt.Printf("  SHA256: %s\n", downloadResult.SHA256)
	if validationResult.Valid {
		fmt.Println("  ✅ Checksum validation: PASSED")
	} else {
		fmt.Println("  ❌ Checksum validation: FAILED")
	}
}

func handleTestConnection() {
	fmt.Println("🔗 Testing network connectivity...")
	
	testURLs := []string{
		"https://api.github.com",
		"https://github.com",
		"https://httpbin.org/get",
	}

	for _, url := range testURLs {
		fmt.Printf("  Testing %s... ", url)
		
		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Get(url)
		if err != nil {
			fmt.Printf("❌ Failed: %v\n", err)
			continue
		}
		defer resp.Body.Close()
		
		fmt.Printf("✅ %s\n", resp.Status)
	}
}

func downloadFile(url, outputPath string) DownloadResult {
	startTime := time.Now()
	
	result := DownloadResult{
		URL:       url,
		LocalPath: outputPath,
		Success:   false,
	}

	fmt.Printf("📥 Downloading: %s\n", url)

	// Create output directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		result.Error = fmt.Sprintf("Failed to create directory: %v", err)
		return result
	}

	// Download file
	resp, err := http.Get(url)
	if err != nil {
		result.Error = fmt.Sprintf("HTTP request failed: %v", err)
		return result
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		result.Error = fmt.Sprintf("HTTP error: %s", resp.Status)
		return result
	}

	// Create output file
	file, err := os.Create(outputPath)
	if err != nil {
		result.Error = fmt.Sprintf("Failed to create file: %v", err)
		return result
	}
	defer file.Close()

	// Copy data and calculate SHA256
	hasher := sha256.New()
	writer := io.MultiWriter(file, hasher)
	
	size, err := io.Copy(writer, resp.Body)
	if err != nil {
		result.Error = fmt.Sprintf("Failed to copy data: %v", err)
		return result
	}

	result.Size = size
	result.SHA256 = hex.EncodeToString(hasher.Sum(nil))
	result.DownloadTime = time.Since(startTime).Milliseconds()
	result.Success = true

	return result
}

func fetchLatestRelease(repo string) (*GitHubRelease, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", repo)
	
	fmt.Printf("🔍 Fetching release info: %s\n", url)

	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GitHub API error: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Failed to read response: %v", err)
	}

	var release GitHubRelease
	if err := json.Unmarshal(body, &release); err != nil {
		return nil, fmt.Errorf("Failed to parse JSON: %v", err)
	}

	return &release, nil
}

func validateChecksum(filePath, expectedSHA256 string) ChecksumValidationResult {
	startTime := time.Now()
	
	result := ChecksumValidationResult{
		FilePath:       filePath,
		ExpectedSHA256: expectedSHA256,
		Valid:          false,
	}

	// Check if file exists
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		result.Error = fmt.Sprintf("File not found: %v", err)
		return result
	}

	result.FileSize = fileInfo.Size()

	// Calculate SHA256
	file, err := os.Open(filePath)
	if err != nil {
		result.Error = fmt.Sprintf("Failed to open file: %v", err)
		return result
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		result.Error = fmt.Sprintf("Failed to read file: %v", err)
		return result
	}

	result.ActualSHA256 = hex.EncodeToString(hasher.Sum(nil))
	result.ValidationTime = time.Since(startTime).Milliseconds()
	result.Valid = strings.EqualFold(result.ActualSHA256, expectedSHA256)

	return result
}

func printDownloadResult(result DownloadResult) {
	fmt.Println("\n📊 Download Result:")
	fmt.Printf("  URL: %s\n", result.URL)
	fmt.Printf("  Local Path: %s\n", result.LocalPath)
	if result.Success {
		fmt.Printf("  ✅ Status: SUCCESS\n")
		fmt.Printf("  📦 Size: %s\n", formatBytes(result.Size))
		fmt.Printf("  🔐 SHA256: %s\n", result.SHA256)
		fmt.Printf("  ⏱️  Time: %dms\n", result.DownloadTime)
	} else {
		fmt.Printf("  ❌ Status: FAILED\n")
		fmt.Printf("  💥 Error: %s\n", result.Error)
	}
}

func printReleaseInfo(release *GitHubRelease) {
	fmt.Println("\n📦 Release Information:")
	fmt.Printf("  Version: %s\n", release.TagName)
	fmt.Printf("  Name: %s\n", release.Name)
	fmt.Printf("  Published: %s\n", release.PublishedAt)
	fmt.Printf("  Assets: %d files\n", len(release.Assets))

	if len(release.Assets) > 0 {
		fmt.Println("\n📁 Available Assets:")
		for _, asset := range release.Assets {
			fmt.Printf("  - %s (%s)\n", asset.Name, formatBytes(asset.Size))
		}
	}
}

func printValidationResult(result ChecksumValidationResult) {
	fmt.Println("\n🔍 Checksum Validation Result:")
	fmt.Printf("  File: %s\n", result.FilePath)
	fmt.Printf("  Size: %s\n", formatBytes(result.FileSize))
	
	if result.Error != "" {
		fmt.Printf("  ❌ Status: FAILED\n")
		fmt.Printf("  💥 Error: %s\n", result.Error)
		return
	}

	fmt.Printf("  🔐 Expected SHA256: %s\n", result.ExpectedSHA256)
	fmt.Printf("  🔐 Actual SHA256:   %s\n", result.ActualSHA256)
	fmt.Printf("  ⏱️  Time: %dms\n", result.ValidationTime)
	
	if result.Valid {
		fmt.Printf("  ✅ Status: VALID\n")
	} else {
		fmt.Printf("  ❌ Status: INVALID\n")
	}
}

func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}