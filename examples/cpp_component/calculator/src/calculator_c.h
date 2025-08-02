#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Result structure for operations that can fail
typedef struct {
    bool success;
    char* error;      // NULL if success is true
    double result;    // Valid only if success is true
} calculation_result_t;

// Operation types for batch operations
typedef enum {
    OP_ADD = 0,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_POWER,
    OP_SQRT,
    OP_FACTORIAL
} operation_type_t;

// Operation structure for batch calculations
typedef struct {
    operation_type_t op;
    double a;
    double b;        // Used for binary operations, ignored for unary
    bool has_b;      // Indicates if b parameter is valid
} operation_t;

// Component information structure
typedef struct {
    char* name;
    char* version;
    char** supported_operations;
    size_t supported_operations_count;
    char* precision;
    uint32_t max_factorial;
} component_info_t;

// Basic arithmetic operations (always succeed, return NaN on invalid input)
double calculator_c_add(double a, double b);
double calculator_c_subtract(double a, double b);
double calculator_c_multiply(double a, double b);

// Operations that can fail
calculation_result_t calculator_c_divide(double a, double b);
calculation_result_t calculator_c_power(double base, double exponent);
calculation_result_t calculator_c_sqrt(double value);
calculation_result_t calculator_c_factorial(uint32_t n);

// Batch operations
calculation_result_t calculator_c_calculate(const operation_t* operation);
calculation_result_t* calculator_c_calculate_batch(const operation_t* operations,
                                                   size_t count,
                                                   size_t* result_count);

// Component metadata
component_info_t calculator_c_get_info(void);

// Mathematical constants
double calculator_c_get_pi(void);
double calculator_c_get_e(void);

// Memory management functions
void calculator_c_free_result(calculation_result_t* result);
void calculator_c_free_results(calculation_result_t* results, size_t count);
void calculator_c_free_component_info(component_info_t* info);

// Utility functions
bool calculator_c_is_valid_number(double n);
double calculator_c_round_to_precision(double value, int decimal_places);
bool calculator_c_approximately_equal(double a, double b, double epsilon);

#ifdef __cplusplus
}
#endif
