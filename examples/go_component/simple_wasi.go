package main

import (
	"fmt"
	"os"
)

// Simple WASI Preview 2 component using TinyGo
// No complex WIT bindings required - just standard Go code
func main() {
	fmt.Println("Hello from Go WASI Component!")

	// Use standard Go APIs that work with WASI
	args := os.Args
	fmt.Printf("Arguments: %v\n", args)

	// Environment variables work with WASI
	path := os.Getenv("PATH")
	if path != "" {
		fmt.Printf("PATH exists: %s\n", path[:20]+"...")
	}

	// File I/O works with WASI
	data := []byte("Hello from Go component\n")
	err := os.WriteFile("/tmp/test.txt", data, 0644)
	if err != nil {
		fmt.Printf("Note: File write failed (expected in sandbox): %v\n", err)
	}

	fmt.Println("Go WASI component executed successfully!")
}
