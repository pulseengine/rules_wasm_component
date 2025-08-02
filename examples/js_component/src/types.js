// JavaScript type documentation for the calculator component
// These are JSDoc type definitions for documentation purposes

/**
 * @typedef {Object} Operation
 * @property {"add" | "subtract" | "multiply" | "divide"} op - The operation type
 * @property {number} a - First operand
 * @property {number} b - Second operand
 */

/**
 * @typedef {Object} CalculationResult
 * @property {boolean} success - Whether the calculation succeeded
 * @property {string | null} error - Error message if any
 * @property {number | null} value - The calculation result
 */

/**
 * @typedef {Object} ComponentInfo
 * @property {string} name - Component name
 * @property {string} version - Component version
 * @property {string[]} supportedOperations - List of supported operations
 */

// Export empty object since JSDoc types are compile-time only
export {};
