package main

import (
	"go.bytecodealliance.org/cm"
)

// This will be replaced with proper generated bindings from wit-bindgen-go
// For now, we'll use a simplified approach that works with TinyGo's WIT support

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
func divide(a, b float64) (bool, *string, *float64) {
	if b == 0 {
		err := "division by zero"
		return false, &err, nil
	}
	result := a / b
	return true, nil, &result
}

//export example_calculator_get_calculator_info
func getCalculatorInfo() (string, string, []string) {
	supportedOps := []string{"add", "subtract", "multiply", "divide"}
	return "Go Calculator Component", "1.0.0", supportedOps
}

// For complex operation struct, we'll need proper generated bindings
// This is a simplified version for demonstration
//
//export example_calculator_calculate
func calculate(opType int, a, b float64) (bool, *string, *float64) {
	var result float64
	var err *string

	switch opType {
	case 0: // add
		result = a + b
	case 1: // subtract
		result = a - b
	case 2: // multiply
		result = a * b
	case 3: // divide
		if b == 0 {
			errMsg := "division by zero"
			err = &errMsg
			return false, err, nil
		}
		result = a / b
	default:
		errMsg := "unsupported operation"
		err = &errMsg
		return false, err, nil
	}

	return true, nil, &result
}

// Main function required by TinyGo, but exports are the actual component interface
func main() {
	// Initialize component - TinyGo handles the component lifecycle
}

// Prevent compiler from removing exports
var _ = add
var _ = subtract
var _ = multiply
var _ = divide
var _ = getCalculatorInfo
var _ = calculate
