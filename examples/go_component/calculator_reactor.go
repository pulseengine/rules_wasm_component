// Package main provides a pure reactor WebAssembly component
// Reactor components use package "main" but with an EMPTY main() function
// This is the TinyGo way to build library components (see TinyGo issue #2703)
package main

// Pure export functions for WIT component interface
// TinyGo will generate proper component exports via -wit-world flag

//export example_calculator_add
func add(a, b float64) float64 {
	return a + b
}

//export example_calculator_subtract
func subtract(a, b float64) float64 {
	return a - b
}

//export example_calculator_multiply
func multiply(a, b float64) float64 {
	return a * b
}

//export example_calculator_divide
func divide(a, b float64) float64 {
	// In a real implementation, this would use WIT result type for error handling
	// For this simple demo, division by zero returns 0
	if b == 0 {
		return 0
	}
	return a / b
}

// EMPTY main() for reactor mode
// This tells TinyGo we want a reactor component, not a command component
// The runtime is initialized in _initialize, not _start
func main() {
	// Reactor component - no main execution needed
}

// Prevent compiler from removing exports
var _ = add
var _ = subtract
var _ = multiply
var _ = divide
