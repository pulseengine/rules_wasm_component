package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

func main() {
	fmt.Println("🌐 Go HTTP Downloader for WebAssembly Components")
	fmt.Println("================================================")

	// Test GitHub API access
	resp, err := http.Get("https://api.github.com/repos/bytecodealliance/wasm-tools/releases/latest")
	if err != nil {
		fmt.Printf("❌ HTTP request failed: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	fmt.Printf("✅ GitHub API Status: %s\n", resp.Status)

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("❌ Failed to read response: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("📦 Response length: %d bytes\n", len(body))
	fmt.Printf("🎯 GitHub API integration successful!\n")
}
