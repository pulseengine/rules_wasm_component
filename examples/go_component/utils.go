package main

import "fmt"

// TestFunction demonstrates calling functions across Go files
func TestFunction(message string) string {
	return fmt.Sprintf("Utils: %s", message)
}

// Add calculates the sum of two integers
func Add(a, b int) int {
	return a + b
}

// Multiply calculates the product of two integers
func Multiply(a, b int) int {
	return a * b
}
