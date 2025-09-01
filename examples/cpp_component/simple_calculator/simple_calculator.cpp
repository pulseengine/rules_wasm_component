#include "simple_calculator.h"
#include "calculator.h"  // Generated WIT bindings

extern "C" {

// Simple C++ implementations without stdlib dependencies
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

// WIT binding implementations - exact names expected by generated bindings
double exports_example_simple_calculator_calc_add(double a, double b) {
    return simple_add(a, b);
}

double exports_example_simple_calculator_calc_subtract(double a, double b) {
    return simple_subtract(a, b);
}

double exports_example_simple_calculator_calc_multiply(double a, double b) {
    return simple_multiply(a, b);
}

double exports_example_simple_calculator_calc_divide(double a, double b) {
    return simple_divide(a, b);
}

} // extern "C"