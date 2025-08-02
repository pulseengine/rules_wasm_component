// JavaScript calculator component
import { Operation, CalculationResult } from "./types.js";

export function add(a, b) {
  return a + b;
}

export function subtract(a, b) {
  return a - b;
}

export function multiply(a, b) {
  return a * b;
}

export function divide(a, b) {
  if (b === 0) {
    return {
      success: false,
      error: "Division by zero is not allowed",
      value: null,
    };
  }

  return {
    success: true,
    error: null,
    value: a / b,
  };
}

export function calculate(operation) {
  try {
    let result;

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
          value: null,
        };
    }

    return {
      success: true,
      error: null,
      value: result,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
      value: null,
    };
  }
}

export function getCalculatorInfo() {
  return {
    name: "JavaScript Calculator Component",
    version: "1.0.0",
    supportedOperations: ["add", "subtract", "multiply", "divide"],
  };
}
