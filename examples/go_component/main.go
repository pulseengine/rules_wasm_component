package main

import (
	"github.com/example/calculator/bindings"
)

func main() {
	// Initialize the component
	bindings.SetExports(&CalculatorImpl{})
}

// CalculatorImpl implements the calculator interface
type CalculatorImpl struct{}

func (c *CalculatorImpl) Add(a, b float64) float64 {
	return a + b
}

func (c *CalculatorImpl) Subtract(a, b float64) float64 {
	return a - b
}

func (c *CalculatorImpl) Multiply(a, b float64) float64 {
	return a * b
}

func (c *CalculatorImpl) Divide(a, b float64) bindings.CalculationResult {
	if b == 0 {
		return bindings.CalculationResult{
			Success: false,
			Error:   bindings.Some("Division by zero is not allowed"),
			Result:  bindings.None[float64](),
		}
	}
	
	return bindings.CalculationResult{
		Success: true,
		Error:   bindings.None[string](),
		Result:  bindings.Some(a / b),
	}
}

func (c *CalculatorImpl) Calculate(operation bindings.Operation) bindings.CalculationResult {
	switch operation.Op {
	case bindings.OperationTypeAdd:
		result := c.Add(operation.A, operation.B)
		return bindings.CalculationResult{
			Success: true,
			Error:   bindings.None[string](),
			Result:  bindings.Some(result),
		}
	case bindings.OperationTypeSubtract:
		result := c.Subtract(operation.A, operation.B)
		return bindings.CalculationResult{
			Success: true,
			Error:   bindings.None[string](),
			Result:  bindings.Some(result),
		}
	case bindings.OperationTypeMultiply:
		result := c.Multiply(operation.A, operation.B)
		return bindings.CalculationResult{
			Success: true,
			Error:   bindings.None[string](),
			Result:  bindings.Some(result),
		}
	case bindings.OperationTypeDivide:
		return c.Divide(operation.A, operation.B)
	default:
		return bindings.CalculationResult{
			Success: false,
			Error:   bindings.Some("Unknown operation"),
			Result:  bindings.None[float64](),
		}
	}
}

func (c *CalculatorImpl) GetCalculatorInfo() bindings.ComponentInfo {
	return bindings.ComponentInfo{
		Name:                "Go Calculator Component",
		Version:             "1.0.0",
		SupportedOperations: []string{"add", "subtract", "multiply", "divide"},
	}
}