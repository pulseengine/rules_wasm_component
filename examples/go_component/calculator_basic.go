package main

import "math"

// Basic Go component that exports calculator functions
// This demonstrates the manual approach without complex generated bindings

//export add
func add(a, b float64) float64 {
	return a + b
}

//export subtract
func subtract(a, b float64) float64 {
	return a - b
}

//export multiply
func multiply(a, b float64) float64 {
	return a * b
}

//export divide
func divide(a, b float64) float64 {
	if b == 0 {
		// Return NaN for division by zero
		return math.NaN()
	}
	return a / b
}

// Main function required by TinyGo
func main() {
	// Component exports are handled by TinyGo's WIT integration
}

// Prevent compiler from removing exports
var _ = add
var _ = subtract
var _ = multiply
var _ = divide
