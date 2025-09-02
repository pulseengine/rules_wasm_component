package main

import (
	"math"

	// Import the generated bindings using full module path
	calculator "example.com/calculator/example/calculator/calculator"
)

// Initialize the calculator component exports with generated bindings
func init() {
	// Assign implementations to the generated Exports struct
	calculator.Exports.Add = func(a, b float64) float64 {
		return a + b
	}

	calculator.Exports.Subtract = func(a, b float64) float64 {
		return a - b
	}

	calculator.Exports.Multiply = func(a, b float64) float64 {
		return a * b
	}

	calculator.Exports.Divide = func(a, b float64) float64 {
		if b == 0 {
			// Return NaN for division by zero
			return math.NaN()
		}
		return a / b
	}
}

// Main function - required by Go but component interface is what gets exported
func main() {
	// The actual functionality is provided via the exports
}
