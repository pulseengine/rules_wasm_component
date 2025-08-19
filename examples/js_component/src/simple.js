// Simple JavaScript component without imports to test basic jco functionality

export function sayHello(name) {
  return `Hello, ${name}!`;
}

export function getTime() {
  return new Date().toISOString();
}

export function add(a, b) {
  return a + b;
}
