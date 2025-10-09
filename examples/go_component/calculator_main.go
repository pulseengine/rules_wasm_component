package main

// DEPRECATED: Manual exports are incompatible with Component Model
//
// This file demonstrates why wit-bindgen-go is required:
//
// 1. //go:wasmexport has type limitations:
//    - Only core WASM types (int32, int64, float32, float64)
//    - Limited return values (typically 1)
//    - No complex types (structs, slices) without manual encoding
//
// 2. Component Model canonical ABI requires:
//    - Proper type lifting/lowering for records, variants, options
//    - Memory management for strings and lists
//    - Correct naming: "example:calculator/calculator@1.0.0#add"
//
// 3. wit-bindgen-go automatically generates:
//    - Wrapper functions with supported types
//    - Type conversion code
//    - Proper struct definitions matching WIT records
//
// See calculator_with_bindings.go for the correct approach using generated bindings.
//
// This file is kept for educational purposes only and will not build.

//go:wasmexport example:calculator/calculator@1.0.0#add
//export example:calculator/calculator@1.0.0#add
func add(a, b float64) float64 {
	return a + b
}

//go:wasmexport example:calculator/calculator@1.0.0#subtract
//export example:calculator/calculator@1.0.0#subtract
func subtract(a, b float64) float64 {
	return a - b
}

//go:wasmexport example:calculator/calculator@1.0.0#multiply
//export example:calculator/calculator@1.0.0#multiply
func multiply(a, b float64) float64 {
	return a * b
}

//go:wasmexport example:calculator/calculator@1.0.0#divide
//export example:calculator/calculator@1.0.0#divide
func divide(a, b float64) (bool, *string, *float64) {
	if b == 0 {
		err := "division by zero"
		return false, &err, nil
	}
	result := a / b
	return true, nil, &result
}

//go:wasmexport example:calculator/calculator@1.0.0#get-calculator-info
//export example:calculator/calculator@1.0.0#get-calculator-info
func getCalculatorInfo() (string, string, []string) {
	supportedOps := []string{"add", "subtract", "multiply", "divide"}
	return "Go Calculator Component", "1.0.0", supportedOps
}

// For complex operation struct, we'll need proper generated bindings
// This is a simplified version for demonstration
//
//go:wasmexport example:calculator/calculator@1.0.0#calculate
//export example:calculator/calculator@1.0.0#calculate
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
	// Component Model exports are handled via //go:wasmexport directives above
}
