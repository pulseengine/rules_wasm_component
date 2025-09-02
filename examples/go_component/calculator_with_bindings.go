package main

import (
	// The generated bindings will be at this path
	"example.com/calculator/example/calculator/calculator"
)

// Initialize the calculator component exports with generated bindings
func init() {
	// Export calculator interface functions using generated bindings
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
			return 0.0 / 0.0
		}
		return a / b
	}

	calculator.Exports.Calculate = func(operation calculator.Operation) calculator.CalculationResult {
		switch operation.Op {
		case calculator.OperationTypeAdd:
			result := operation.A + operation.B
			return calculator.CalculationResult{
				Success: true,
				Error:   cm.None[string](),
				Value:   cm.Some(result),
			}
		case calculator.OperationTypeSubtract:
			result := operation.A - operation.B
			return calculator.CalculationResult{
				Success: true,
				Error:   cm.None[string](),
				Value:   cm.Some(result),
			}
		case calculator.OperationTypeMultiply:
			result := operation.A * operation.B
			return calculator.CalculationResult{
				Success: true,
				Error:   cm.None[string](),
				Value:   cm.Some(result),
			}
		case calculator.OperationTypeDivide:
			if operation.B == 0 {
				return calculator.CalculationResult{
					Success: false,
					Error:   cm.Some("division by zero"),
					Value:   cm.None[float64](),
				}
			}
			result := operation.A / operation.B
			return calculator.CalculationResult{
				Success: true,
				Error:   cm.None[string](),
				Value:   cm.Some(result),
			}
		default:
			return calculator.CalculationResult{
				Success: false,
				Error:   cm.Some("unsupported operation"),
				Value:   cm.None[float64](),
			}
		}
	}

	calculator.Exports.GetCalculatorInfo = func() calculator.ComponentInfo {
		return calculator.ComponentInfo{
			Name:    "Go Calculator Component",
			Version: "1.0.0",
			SupportedOperations: cm.ToList([]string{
				"add", "subtract", "multiply", "divide",
			}),
		}
	}
}

// Component main - required but empty for WIT components
func main() {}
