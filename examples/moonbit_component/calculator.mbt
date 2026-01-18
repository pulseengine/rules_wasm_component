/// MoonBit WebAssembly Component Example - Calculator
///
/// Implements arithmetic operations exported via the calculator WIT interface.
/// This demonstrates how MoonBit code integrates with the WebAssembly Component Model.

/// Add two integers.
pub fn add(a : Int, b : Int) -> Int {
  a + b
}

/// Subtract b from a.
pub fn subtract(a : Int, b : Int) -> Int {
  a - b
}

/// Multiply two integers.
pub fn multiply(a : Int, b : Int) -> Int {
  a * b
}

/// Divide a by b, returning 0 if b is zero.
pub fn divide(a : Int, b : Int) -> Int {
  if b == 0 {
    0
  } else {
    a / b
  }
}
