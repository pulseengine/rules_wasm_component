#include "calculator_cpp.h"  // Generated C++ WIT bindings

// Simple C++ implementations without stdlib dependencies
namespace {

double simple_add(double a, double b) {
    return a + b;
}

double simple_subtract(double a, double b) {
    return a - b;
}

double simple_multiply(double a, double b) {
    return a * b;
}

double simple_divide(double a, double b) {
    if (b == 0.0) {
        return 0.0;  // Simple error handling
    }
    return a / b;
}

} // anonymous namespace

// C++ bindings API implementation using namespaces
namespace exports {
namespace example {
namespace simple_calculator {
namespace calc {

double Add(double a, double b) {
    return simple_add(a, b);
}

double Subtract(double a, double b) {
    return simple_subtract(a, b);
}

double Multiply(double a, double b) {
    return simple_multiply(a, b);
}

double Divide(double a, double b) {
    return simple_divide(a, b);
}

}}}} // namespace exports::example::simple_calculator::calc
