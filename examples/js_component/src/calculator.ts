// TypeScript calculator component
import { Operation, CalculationResult } from "./types";

export function add(a: number, b: number): number {
  return a + b;
}

export function subtract(a: number, b: number): number {
  return a - b;
}

export function multiply(a: number, b: number): number {
  return a * b;
}

export function divide(a: number, b: number): CalculationResult {
  if (b === 0) {
    return {
      success: false,
      error: "Division by zero is not allowed",
      result: null,
    };
  }

  return {
    success: true,
    error: null,
    result: a / b,
  };
}

export function calculate(operation: Operation): CalculationResult {
  try {
    let result: number;

    switch (operation.op) {
      case "add":
        result = add(operation.a, operation.b);
        break;
      case "subtract":
        result = subtract(operation.a, operation.b);
        break;
      case "multiply":
        result = multiply(operation.a, operation.b);
        break;
      case "divide":
        return divide(operation.a, operation.b);
      default:
        return {
          success: false,
          error: `Unknown operation: ${operation.op}`,
          result: null,
        };
    }

    return {
      success: true,
      error: null,
      result: result,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
      result: null,
    };
  }
}

export function getCalculatorInfo() {
  return {
    name: "TypeScript Calculator Component",
    version: "1.0.0",
    supportedOperations: ["add", "subtract", "multiply", "divide"],
  };
}
