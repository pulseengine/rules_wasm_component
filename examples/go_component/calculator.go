package main

import (
	"fmt"
	"math"
)

// MathUtils provides additional mathematical utility functions
type MathUtils struct{}

// Power calculates a raised to the power of b
func (m *MathUtils) Power(a, b float64) float64 {
	return math.Pow(a, b)
}

// SquareRoot calculates the square root of a number
func (m *MathUtils) SquareRoot(a float64) (float64, error) {
	if a < 0 {
		return 0, fmt.Errorf("cannot calculate square root of negative number: %f", a)
	}
	return math.Sqrt(a), nil
}

// Factorial calculates the factorial of a non-negative integer
func (m *MathUtils) Factorial(n int) (int64, error) {
	if n < 0 {
		return 0, fmt.Errorf("factorial is not defined for negative numbers: %d", n)
	}
	
	if n == 0 || n == 1 {
		return 1, nil
	}
	
	result := int64(1)
	for i := 2; i <= n; i++ {
		result *= int64(i)
		// Check for overflow
		if result < 0 {
			return 0, fmt.Errorf("factorial overflow for input: %d", n)
		}
	}
	
	return result, nil
}

// IsValidNumber checks if a float64 is a valid number (not NaN or Inf)
func (m *MathUtils) IsValidNumber(n float64) bool {
	return !math.IsNaN(n) && !math.IsInf(n, 0)
}

// Round rounds a number to the specified number of decimal places
func (m *MathUtils) Round(n float64, decimals int) float64 {
	multiplier := math.Pow(10, float64(decimals))
	return math.Round(n*multiplier) / multiplier
}

// Percentage calculates what percentage 'part' is of 'whole'
func (m *MathUtils) Percentage(part, whole float64) (float64, error) {
	if whole == 0 {
		return 0, fmt.Errorf("cannot calculate percentage with zero as whole")
	}
	return (part / whole) * 100, nil
}

// ValidateOperation checks if an operation can be performed safely
func ValidateOperation(op string, a, b float64) error {
	utils := &MathUtils{}
	
	if !utils.IsValidNumber(a) || !utils.IsValidNumber(b) {
		return fmt.Errorf("invalid numbers provided: a=%f, b=%f", a, b)
	}
	
	switch op {
	case "divide":
		if b == 0 {
			return fmt.Errorf("division by zero")
		}
	case "power":
		// Check for potential overflow conditions
		if a == 0 && b < 0 {
			return fmt.Errorf("zero raised to negative power is undefined")
		}
	}
	
	return nil
}