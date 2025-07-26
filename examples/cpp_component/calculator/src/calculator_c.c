#include "calculator_c.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <float.h>
#include <stdio.h>

// Mathematical constants
#define PI 3.141592653589793
#define E  2.718281828459045
#define EPSILON 1e-10
#define MAX_FACTORIAL 20
#define PRECISION_DIGITS 15

// Helper function to create error results
static calculation_result_t create_error(const char* message) {
    calculation_result_t result;
    result.success = false;
    result.error = malloc(strlen(message) + 1);
    if (result.error) {
        strcpy(result.error, message);
    }
    result.result = 0.0;
    return result;
}

// Helper function to create success results
static calculation_result_t create_success(double value) {
    calculation_result_t result;
    result.success = true;
    result.error = NULL;
    result.result = value;
    return result;
}

// Utility functions
bool calculator_c_is_valid_number(double n) {
    return !isnan(n) && !isinf(n);
}

double calculator_c_round_to_precision(double value, int decimal_places) {
    if (!isfinite(value)) {
        return value;
    }
    
    double multiplier = pow(10.0, decimal_places);
    return round(value * multiplier) / multiplier;
}

bool calculator_c_approximately_equal(double a, double b, double epsilon) {
    return fabs(a - b) < epsilon;
}

// Safe mathematical operations
static bool safe_factorial_uint64(uint32_t n, uint64_t* result) {
    if (n > MAX_FACTORIAL) {
        return false;
    }
    
    if (n == 0 || n == 1) {
        *result = 1;
        return true;
    }
    
    uint64_t factorial = 1;
    for (uint32_t i = 2; i <= n; ++i) {
        // Check for overflow
        if (factorial > UINT64_MAX / i) {
            return false;
        }
        factorial *= i;
    }
    
    *result = factorial;
    return true;
}

// Basic arithmetic operations
double calculator_c_add(double a, double b) {
    if (!calculator_c_is_valid_number(a) || !calculator_c_is_valid_number(b)) {
        return NAN;
    }
    return calculator_c_round_to_precision(a + b, PRECISION_DIGITS);
}

double calculator_c_subtract(double a, double b) {
    if (!calculator_c_is_valid_number(a) || !calculator_c_is_valid_number(b)) {
        return NAN;
    }
    return calculator_c_round_to_precision(a - b, PRECISION_DIGITS);
}

double calculator_c_multiply(double a, double b) {
    if (!calculator_c_is_valid_number(a) || !calculator_c_is_valid_number(b)) {
        return NAN;
    }
    return calculator_c_round_to_precision(a * b, PRECISION_DIGITS);
}

// Operations that can fail
calculation_result_t calculator_c_divide(double a, double b) {
    if (!calculator_c_is_valid_number(a) || !calculator_c_is_valid_number(b)) {
        return create_error("Invalid input numbers");
    }
    
    if (calculator_c_approximately_equal(b, 0.0, EPSILON)) {
        return create_error("Division by zero is not allowed");
    }
    
    double result = a / b;
    if (!isfinite(result)) {
        return create_error("Division resulted in invalid number");
    }
    
    return create_success(calculator_c_round_to_precision(result, PRECISION_DIGITS));
}

calculation_result_t calculator_c_power(double base, double exponent) {
    if (!calculator_c_is_valid_number(base) || !calculator_c_is_valid_number(exponent)) {
        return create_error("Invalid input numbers");
    }
    
    // Handle special cases
    if (calculator_c_approximately_equal(base, 0.0, EPSILON) && exponent < 0) {
        return create_error("Zero to negative power is undefined");
    }
    
    if (base < 0 && floor(exponent) != exponent) {
        return create_error("Negative base with non-integer exponent is not supported");
    }
    
    double result = pow(base, exponent);
    if (!isfinite(result)) {
        char error_msg[128];
        snprintf(error_msg, sizeof(error_msg), "Power operation failed: %.6f^%.6f", base, exponent);
        return create_error(error_msg);
    }
    
    return create_success(calculator_c_round_to_precision(result, PRECISION_DIGITS));
}

calculation_result_t calculator_c_sqrt(double value) {
    if (!calculator_c_is_valid_number(value)) {
        return create_error("Invalid input number");
    }
    
    if (value < 0) {
        return create_error("Square root of negative number is not supported");
    }
    
    double result = sqrt(value);
    return create_success(calculator_c_round_to_precision(result, PRECISION_DIGITS));
}

calculation_result_t calculator_c_factorial(uint32_t n) {
    uint64_t factorial_result;
    if (!safe_factorial_uint64(n, &factorial_result)) {
        char error_msg[64];
        snprintf(error_msg, sizeof(error_msg), "Factorial of %u is too large or not supported", n);
        return create_error(error_msg);
    }
    
    return create_success((double)factorial_result);
}

// Batch operations
calculation_result_t calculator_c_calculate(const operation_t* operation) {
    if (!operation) {
        return create_error("Null operation pointer");
    }
    
    switch (operation->op) {
        case OP_ADD:
            if (!operation->has_b) {
                return create_error("Add operation requires two operands");
            }
            return create_success(calculator_c_add(operation->a, operation->b));
            
        case OP_SUBTRACT:
            if (!operation->has_b) {
                return create_error("Subtract operation requires two operands");
            }
            return create_success(calculator_c_subtract(operation->a, operation->b));
            
        case OP_MULTIPLY:
            if (!operation->has_b) {
                return create_error("Multiply operation requires two operands");
            }
            return create_success(calculator_c_multiply(operation->a, operation->b));
            
        case OP_DIVIDE:
            if (!operation->has_b) {
                return create_error("Divide operation requires two operands");
            }
            return calculator_c_divide(operation->a, operation->b);
            
        case OP_POWER:
            if (!operation->has_b) {
                return create_error("Power operation requires two operands");
            }
            return calculator_c_power(operation->a, operation->b);
            
        case OP_SQRT:
            return calculator_c_sqrt(operation->a);
            
        case OP_FACTORIAL:
            if (operation->a < 0 || floor(operation->a) != operation->a) {
                return create_error("Factorial requires a non-negative integer");
            }
            return calculator_c_factorial((uint32_t)operation->a);
            
        default:
            return create_error("Unknown operation type");
    }
}

calculation_result_t* calculator_c_calculate_batch(const operation_t* operations, 
                                                   size_t count, 
                                                   size_t* result_count) {
    if (!operations || count == 0) {
        if (result_count) *result_count = 0;
        return NULL;
    }
    
    calculation_result_t* results = malloc(count * sizeof(calculation_result_t));
    if (!results) {
        if (result_count) *result_count = 0;
        return NULL;
    }
    
    for (size_t i = 0; i < count; ++i) {
        results[i] = calculator_c_calculate(&operations[i]);
    }
    
    if (result_count) *result_count = count;
    return results;
}

// Component metadata
component_info_t calculator_c_get_info(void) {
    component_info_t info;
    
    // Allocate and copy strings
    info.name = malloc(strlen("C Calculator Component") + 1);
    strcpy(info.name, "C Calculator Component");
    
    info.version = malloc(strlen("1.0.0") + 1);
    strcpy(info.version, "1.0.0");
    
    info.precision = malloc(strlen("IEEE 754 double precision (15-17 decimal digits)") + 1);
    strcpy(info.precision, "IEEE 754 double precision (15-17 decimal digits)");
    
    // Supported operations
    const char* operations[] = {"add", "subtract", "multiply", "divide", "power", "sqrt", "factorial"};
    info.supported_operations_count = 7;
    info.supported_operations = malloc(info.supported_operations_count * sizeof(char*));
    
    for (size_t i = 0; i < info.supported_operations_count; ++i) {
        info.supported_operations[i] = malloc(strlen(operations[i]) + 1);
        strcpy(info.supported_operations[i], operations[i]);
    }
    
    info.max_factorial = MAX_FACTORIAL;
    
    return info;
}

// Mathematical constants
double calculator_c_get_pi(void) {
    return PI;
}

double calculator_c_get_e(void) {
    return E;
}

// Memory management functions
void calculator_c_free_result(calculation_result_t* result) {
    if (result && result->error) {
        free(result->error);
        result->error = NULL;
    }
}

void calculator_c_free_results(calculation_result_t* results, size_t count) {
    if (!results) return;
    
    for (size_t i = 0; i < count; ++i) {
        calculator_c_free_result(&results[i]);
    }
    free(results);
}

void calculator_c_free_component_info(component_info_t* info) {
    if (!info) return;
    
    if (info->name) {
        free(info->name);
        info->name = NULL;
    }
    
    if (info->version) {
        free(info->version);
        info->version = NULL;
    }
    
    if (info->precision) {
        free(info->precision);
        info->precision = NULL;
    }
    
    if (info->supported_operations) {
        for (size_t i = 0; i < info->supported_operations_count; ++i) {
            if (info->supported_operations[i]) {
                free(info->supported_operations[i]);
            }
        }
        free(info->supported_operations);
        info->supported_operations = NULL;
    }
    
    info->supported_operations_count = 0;
    info->max_factorial = 0;
}

// WIT interface implementation for C
// These functions will be called by the generated WIT bindings

extern double calculator_add(double a, double b) {
    return calculator_c_add(a, b);
}

extern double calculator_subtract(double a, double b) {
    return calculator_c_subtract(a, b);
}

extern double calculator_multiply(double a, double b) {
    return calculator_c_multiply(a, b);
}

// For operations that return results, we need to handle WIT binding structures
// These are placeholders that will be properly implemented once WIT bindings are generated
extern void calculator_divide(double a, double b, void* result_ptr) {
    calculation_result_t result = calculator_c_divide(a, b);
    // Implementation depends on generated binding structure
    // For now, this is a placeholder
    calculator_c_free_result(&result);
}

extern void calculator_power(double base, double exponent, void* result_ptr) {
    calculation_result_t result = calculator_c_power(base, exponent);
    // Implementation depends on generated binding structure
    calculator_c_free_result(&result);
}

extern void calculator_sqrt(double value, void* result_ptr) {
    calculation_result_t result = calculator_c_sqrt(value);
    // Implementation depends on generated binding structure
    calculator_c_free_result(&result);
}

extern void calculator_factorial(uint32_t n, void* result_ptr) {
    calculation_result_t result = calculator_c_factorial(n);
    // Implementation depends on generated binding structure
    calculator_c_free_result(&result);
}

extern double calculator_get_pi(void) {
    return calculator_c_get_pi();
}

extern double calculator_get_e(void) {
    return calculator_c_get_e();
}