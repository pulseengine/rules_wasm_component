// Main entry point for the hello JavaScript component
// Inline the formatMessage function to avoid ES6 import issues in componentize-js
function formatMessage(name) {
  const timestamp = new Date().toISOString();
  return `Hello, ${name}! Message generated at ${timestamp}`;
}

// Component implementation matching the WIT interface
function sayHello(name) {
  const processedName =
    name.charAt(0).toUpperCase() + name.slice(1).toLowerCase();
  return formatMessage(processedName);
}

function greetMultiple(names) {
  return names.map((name) => sayHello(name));
}

function getComponentInfo() {
  return {
    name: "Hello JavaScript Component",
    version: "1.0.0",
    description: "A WebAssembly component built from JavaScript using jco",
    features: ["greeting", "batch-processing"],
  };
}

// Export the hello interface as expected by the WIT world
export const hello = {
  sayHello,
  greetMultiple,
  getComponentInfo,
};
