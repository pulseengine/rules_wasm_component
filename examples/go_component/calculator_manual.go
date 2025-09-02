package main

// Manual calculator exports using TinyGo's built-in WIT support
// This should work with TinyGo's --wit-package and --wit-world flags

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

// Component main - TinyGo handles WIT component lifecycle
func main() {}

// Keep exports alive
var _ = add
var _ = subtract
var _ = multiply
var _ = divide
