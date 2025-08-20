// JavaScript calculator component
// Remove ES6 import to avoid module resolution issues with componentize-js

function add(a, b) {
  return a + b;
}

function subtract(a, b) {
  return a - b;
}

function multiply(a, b) {
  return a * b;
}

function divide(a, b) {
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

function calculate(operation) {
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

function getCalculatorInfo() {
  return {
    name: "JavaScript Calculator Component",
    version: "1.0.0",
    supportedOperations: ["add", "subtract", "multiply", "divide"],
  };
}

// Export the calc interface as expected by the WIT world
export const calc = {
  add,
  subtract,
  multiply,
  divide,
  calculate,
  getCalculatorInfo,
};
