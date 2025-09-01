package main

import "fmt"

// Simple Go component that compiles to WASI Preview 2
// No WIT bindings required - just standard Go
func main() {
	fmt.Println("Hello from simple Go WASI component!")
	fmt.Println("This is a basic WASI Preview 2 component built with TinyGo")
	
	// Simple calculation
	result := add(5, 3)
	fmt.Printf("5 + 3 = %d\n", result)
}

func add(a, b int) int {
	return a + b
}