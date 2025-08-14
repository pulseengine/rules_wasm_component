/*
HTTP Downloader WebAssembly Component

This Go component provides HTTP downloading capabilities for GitHub releases,
showcasing TinyGo + WASI Preview 2 networking in a real-world WebAssembly component.
*/

package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// GitHub API base URLs
const githubAPIBase = "https://api.github.com"
const githubReleaseBase = "https://github.com"

// HTTP client with timeout
var client = &http.Client{
	Timeout: 30 * time.Second,
}

// main function is the entry point for the WebAssembly component
func main() {
	log.Println("🌐 HTTP Downloader WebAssembly Component initialized")
	log.Println("🚀 Ready to download GitHub releases with WASI Preview 2")
	
	// Test basic HTTP functionality
	testHTTPDownloader()
}

// Test HTTP downloader functionality
func testHTTPDownloader() {
	log.Println("🔍 Testing HTTP downloader functionality...")
	
	// Simple HTTP request test
	result := GetLatestRelease("bytecodealliance/wasm-tools")
	if result.Success != nil {
		log.Printf("✅ HTTP test successful: %d bytes", len(result.Success.Body))
	} else if result.HTTPError != nil {
		log.Printf("❌ HTTP error: %d - %s", result.HTTPError.Status, result.HTTPError.Message)
	} else {
		log.Printf("❌ Request failed: %s", result.Error)
	}
}

// DownloadResult represents the result of a download operation
type DownloadResult struct {
	Success   *ResponseData   `json:"success,omitempty"`
	HTTPError *HTTPErrorInfo `json:"http_error,omitempty"`
	Error     string         `json:"error,omitempty"`
}

// ResponseData represents HTTP response data
type ResponseData struct {
	Status  uint16              `json:"status"`
	Headers []HeaderPair        `json:"headers"`
	Body    []byte              `json:"body"`
}

// HTTPErrorInfo represents HTTP error information
type HTTPErrorInfo struct {
	Status  uint16 `json:"status"`
	Message string `json:"message"`
}

// HeaderPair represents an HTTP header key-value pair
type HeaderPair struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

// DownloadGithubReleaseAsset downloads a specific asset from a GitHub release
func DownloadGithubReleaseAsset(repo, version, assetName string) DownloadResult {
	log.Printf("📥 Downloading GitHub asset: %s/%s - %s", repo, version, assetName)
	
	// Construct download URL for GitHub release asset
	url := fmt.Sprintf("%s/%s/releases/download/%s/%s", githubReleaseBase, repo, version, assetName)
	
	return makeHTTPRequest("GET", url, "application/octet-stream")
}

// DownloadGithubChecksums downloads checksums from a GitHub release
func DownloadGithubChecksums(repo, version string) DownloadResult {
	log.Printf("🔍 Downloading GitHub checksums: %s/%s", repo, version)
	
	// Common checksum file names to try
	checksumFiles := []string{
		"SHASUMS256.txt",
		"SHA256SUMS.txt", 
		"checksums.txt",
		"sha256sums.txt",
	}
	
	// Try each potential checksum file
	for _, filename := range checksumFiles {
		url := fmt.Sprintf("%s/%s/releases/download/%s/%s", githubReleaseBase, repo, version, filename)
		result := makeHTTPRequest("GET", url, "text/plain")
		
		// If we found a checksum file, return it
		if result.Success != nil && result.Success.Status == 200 {
			log.Printf("✅ Found checksums in: %s", filename)
			return result
		}
	}
	
	return DownloadResult{
		Error: fmt.Sprintf("No checksum files found for %s/%s", repo, version),
	}
}

// GetLatestRelease gets the latest release information from GitHub API
func GetLatestRelease(repo string) DownloadResult {
	log.Printf("🔍 Getting latest release: %s", repo)
	
	// GitHub API endpoint for latest release
	url := fmt.Sprintf("%s/repos/%s/releases/latest", githubAPIBase, repo)
	
	return makeHTTPRequest("GET", url, "application/vnd.github.v3+json")
}

// makeHTTPRequest performs an HTTP request and returns the result
func makeHTTPRequest(method, url, acceptType string) DownloadResult {
	log.Printf("🌐 HTTP %s: %s", method, url)
	
	// Create HTTP request without context (TinyGo doesn't support goroutines)
	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		return DownloadResult{
			Error: fmt.Sprintf("Failed to create request: %v", err),
		}
	}
	
	// Set headers
	req.Header.Set("Accept", acceptType)
	req.Header.Set("User-Agent", "WebAssembly-Component-HTTP-Downloader/1.0")
	
	// Make the request
	resp, err := client.Do(req)
	if err != nil {
		return DownloadResult{
			Error: fmt.Sprintf("HTTP request failed: %v", err),
		}
	}
	defer resp.Body.Close()
	
	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return DownloadResult{
			Error: fmt.Sprintf("Failed to read response body: %v", err),
		}
	}
	
	// Convert headers
	var headers []HeaderPair
	for name, values := range resp.Header {
		for _, value := range values {
			headers = append(headers, HeaderPair{
				Name:  name,
				Value: value,
			})
		}
	}
	
	// Check for HTTP errors
	if resp.StatusCode >= 400 {
		return DownloadResult{
			HTTPError: &HTTPErrorInfo{
				Status:  uint16(resp.StatusCode),
				Message: fmt.Sprintf("HTTP %d: %s", resp.StatusCode, string(body)),
			},
		}
	}
	
	// Success
	log.Printf("✅ HTTP %d - Downloaded %d bytes", resp.StatusCode, len(body))
	
	return DownloadResult{
		Success: &ResponseData{
			Status:  uint16(resp.StatusCode),
			Headers: headers,
			Body:    body,
		},
	}
}

// Wizer initialization function for pre-initialization
//export wizer.initialize  
func wizerInitialize() {
	log.Println("🚀 Wizer pre-initialization: HTTP client ready")
	
	// Pre-warm the HTTP client and DNS resolution
	// This expensive setup happens at build time, not runtime (without goroutines)
	req, _ := http.NewRequest("HEAD", "https://api.github.com", nil)
	req.Header.Set("User-Agent", "WebAssembly-Component-HTTP-Downloader/1.0")
	
	if resp, err := client.Do(req); err == nil {
		resp.Body.Close()
		log.Println("🌐 GitHub API connectivity verified during Wizer init")
	}
}

// Export functions for WebAssembly component interface
//export download-github-release-asset
func exportDownloadGithubReleaseAsset(repo, version, assetName string) DownloadResult {
	return DownloadGithubReleaseAsset(repo, version, assetName)
}

//export download-github-checksums  
func exportDownloadGithubChecksums(repo, version string) DownloadResult {
	return DownloadGithubChecksums(repo, version)
}

//export get-latest-release
func exportGetLatestRelease(repo string) DownloadResult {
	return GetLatestRelease(repo)
}