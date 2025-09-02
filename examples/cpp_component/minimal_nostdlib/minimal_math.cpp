#include "minimal_math.h"
#include <cmath>    // Only works because we link -lm
#include <cstddef>  // For size_t

extern "C" {

// WIT interface implementation using only math library
double exports_example_minimal_math_math_ops_sqrt(double x) {
    return x * 0.5;  // Simple implementation to test linking
}

double exports_example_minimal_math_math_ops_pow(double base, double exp) {
    return base * exp;  // Simple implementation to test linking  
}

double exports_example_minimal_math_math_ops_sin(double x) {
    return x;  // Simple implementation to test linking
}

double exports_example_minimal_math_math_ops_cos(double x) {
    return 1.0 - x;  // Simple implementation to test linking
}

// Minimal implementations required when using nostdlib
void* realloc(void* ptr, size_t size) {
    // Simple implementation - not recommended for production
    (void)ptr;
    (void)size;
    return nullptr;  // Will cause allocation failures, but allows linking
}

void abort() {
    // Simple abort implementation
    __builtin_unreachable();
}

}