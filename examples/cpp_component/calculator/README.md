# C/C++ Calculator Component Example

This example demonstrates how to create WebAssembly components using C and C++ with the Component Model (Preview2). It implements a comprehensive calculator with advanced mathematical operations, error handling, and batch processing capabilities.

## Features

- **Basic Operations**: Addition, subtraction, multiplication
- **Advanced Operations**: Division, power, square root, factorial
- **Batch Processing**: Execute multiple operations in a single call
- **Error Handling**: Comprehensive error reporting for invalid operations
- **Mathematical Constants**: Access to π and e
- **Component Metadata**: Information about supported operations and precision
- **Both C and C++ Implementations**: Demonstrates different language approaches

## Architecture

The example includes both C and C++ implementations:

### C++ Implementation (`calculator.cpp`, `calculator.h`)

- Object-oriented design with the `Calculator` class
- Uses modern C++ features like `std::optional` and `enum class`
- Comprehensive error handling with custom result types
- Template-based utility functions

### C Implementation (`calculator_c.c`, `calculator_c.h`)

- Procedural design with C-style structs and functions
- Manual memory management with explicit cleanup functions
- Compatible with C99 standard
- Comprehensive error handling with result structures

### Shared Utilities (`math_utils.cpp`, `math_utils.h`)

- Safe mathematical operations with overflow protection
- Precision control and rounding
- Input validation and error checking
- Batch operation support

## Building and Running

### Build the Component

```bash
# Build C++ version
bazel build //examples/cpp_component/calculator:calculator_cpp_component

# Build C version
bazel build //examples/cpp_component/calculator:calculator_c_component

# Build tests
bazel build //examples/cpp_component/calculator:calculator_test
```

### Run Tests

```bash
bazel test //examples/cpp_component/calculator:calculator_test
```

### Inspect the Generated Component

```bash
# View component structure
wasm-tools component wit examples/cpp_component/calculator/bazel-bin/calculator_cpp_component.wasm

# Validate component
wasm-tools validate examples/cpp_component/calculator/bazel-bin/calculator_cpp_component.wasm --features component-model
```

## WIT Interface

The calculator component exports the following interface defined in `wit/calculator.wit`:

```wit
interface calculator {
    // Basic arithmetic operations
    add: func(a: f64, b: f64) -> f64;
    subtract: func(a: f64, b: f64) -> f64;
    multiply: func(a: f64, b: f64) -> f64;

    // Operations that can fail
    divide: func(a: f64, b: f64) -> calculation-result;
    power: func(base: f64, exponent: f64) -> calculation-result;
    sqrt: func(value: f64) -> calculation-result;
    factorial: func(n: u32) -> calculation-result;

    // Batch operations
    calculate: func(operation: operation) -> calculation-result;
    calculate-batch: func(operations: list<operation>) -> list<calculation-result>;

    // Component metadata
    get-calculator-info: func() -> component-info;

    // Mathematical constants
    get-pi: func() -> f64;
    get-e: func() -> f64;
}
```

## Usage Examples

### Basic Operations

```cpp
// C++ usage
calculator::Calculator calc;
double result = calc.add(2.0, 3.0);  // 5.0

// C usage
double result = calculator_c_add(2.0, 3.0);  // 5.0
```

### Error Handling

```cpp
// C++ usage
auto result = calc.divide(10.0, 0.0);
if (!result.success) {
    std::cout << "Error: " << result.error.value() << std::endl;
}

// C usage
calculation_result_t result = calculator_c_divide(10.0, 0.0);
if (!result.success) {
    printf("Error: %s\n", result.error);
    calculator_c_free_result(&result);
}
```

### Batch Operations

```cpp
// C++ usage
std::vector<calculator::Calculator::Operation> ops = {
    {calculator::Calculator::OperationType::Add, 2.0, 3.0},
    {calculator::Calculator::OperationType::Sqrt, 16.0, std::nullopt}
};
auto results = calc.calculate_batch(ops);

// C usage
operation_t ops[] = {
    {OP_ADD, 2.0, 3.0, true},
    {OP_SQRT, 16.0, 0.0, false}
};
size_t count;
calculation_result_t* results = calculator_c_calculate_batch(ops, 2, &count);
calculator_c_free_results(results, count);
```

## Key Implementation Details

### Preview2 Direct Compilation

- Compiles directly to `wasm32-wasip2` target
- No Preview1 → Preview2 adapters needed
- Uses component model interface types

### Memory Management

- **C++**: RAII and smart pointers for automatic cleanup
- **C**: Explicit cleanup functions to prevent memory leaks
- All error messages are dynamically allocated and must be freed

### Error Handling

- Comprehensive validation of all inputs
- Clear error messages for all failure cases
- Safe operations that prevent undefined behavior
- Overflow protection for large calculations

### Mathematical Precision

- IEEE 754 double precision (15-17 decimal digits)
- Configurable rounding to prevent floating-point drift
- Approximate equality comparisons with configurable epsilon
- Special handling for edge cases (NaN, infinity, etc.)

## Testing

The example includes comprehensive tests covering:

- All basic and advanced operations
- Error conditions and edge cases
- Batch operation functionality
- Component metadata retrieval
- Memory management (C version)
- Both C and C++ implementations

Run the tests to verify functionality:

```bash
bazel test //examples/cpp_component/calculator:calculator_test --test_output=all
```

## Integration

This component can be integrated into larger systems:

- **Compose with other components** using WAC (WebAssembly Composition)
- **Call from host applications** using wasmtime or other component runtimes
- **Export to registries** using wasm-pkg-tools (wkg)
- **Use in multi-language projects** by calling from Rust, JavaScript, etc.

## Performance Considerations

- **Minimal overhead**: Direct Preview2 compilation
- **Efficient batch operations**: Process multiple calculations in single calls
- **Memory efficient**: Careful memory management in C version
- **Fast mathematical operations**: Optimized using standard library functions
