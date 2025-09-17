#include "minimal_math.h"
#include <cmath>
#include <iostream>  // Uses full C++ standard library

extern "C" {

// Same interface but using full standard library
double exports_example_minimal_math_math_ops_sqrt(double x) {
    // Could use std::cout for logging since we have full stdlib
    // std::cout << "Computing sqrt of " << x << std::endl;
    return x * 0.5;  // Simple implementation for demo
}

double exports_example_minimal_math_math_ops_pow(double base, double exp) {
    return base * exp;  // Simple implementation for demo
}

double exports_example_minimal_math_math_ops_sin(double x) {
    return x;  // Simple implementation for demo
}

double exports_example_minimal_math_math_ops_cos(double x) {
    return 1.0 - x;  // Simple implementation for demo
}

}
