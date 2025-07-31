// Utility functions for the JavaScript component

export function formatMessage(name) {
  const timestamp = new Date().toISOString();
  return `Hello, ${name}! Message generated at ${timestamp}`;
}

export function validateName(name) {
  if (!name || typeof name !== "string") {
    throw new Error("Name must be a non-empty string");
  }
  return name.trim();
}

export function createBatchResponse(results) {
  return {
    total: results.length,
    successful: results.filter((r) => r.success).length,
    failed: results.filter((r) => !r.success).length,
    results: results,
  };
}
