#include "calculator_impl.h"
#include <cmath>
#include <vector>
#include <algorithm>

namespace calculator {

// Basic arithmetic operations - simplified to avoid math_utils dependencies
double Calculator::add(double a, double b) const {
    return a + b;
}

double Calculator::subtract(double a, double b) const {
    return a - b;
}

double Calculator::multiply(double a, double b) const {
    return a * b;
}

// Operations that can fail - simplified
Calculator::CalculationResult Calculator::divide(double a, double b) const {
    if (b == 0.0) {
        return create_error("Division by zero is not allowed");
    }
    return create_success(a / b);
}

Calculator::CalculationResult Calculator::power(double base, double exponent) const {
    double result = pow(base, exponent);
    return create_success(result);
}

Calculator::CalculationResult Calculator::sqrt(double value) const {
    if (value < 0.0) {
        return create_error("Square root of negative number is not supported");
    }
    double result = ::sqrt(value);
    return create_success(result);
}

Calculator::CalculationResult Calculator::factorial(uint32_t n) const {
    if (n > 20) {
        return create_error("Factorial too large");
    }
    double result = 1.0;
    for (uint32_t i = 2; i <= n; i++) {
        result *= i;
    }
    return create_success(result);
}

// Batch operations
Calculator::CalculationResult Calculator::calculate(const Operation& operation) const {
    switch (operation.op) {
        case OperationType::Add:
            if (!operation.b.has_value()) {
                return create_error("Add operation requires two operands");
            }
            return create_success(add(operation.a, operation.b.value()));

        case OperationType::Subtract:
            if (!operation.b.has_value()) {
                return create_error("Subtract operation requires two operands");
            }
            return create_success(subtract(operation.a, operation.b.value()));

        case OperationType::Multiply:
            if (!operation.b.has_value()) {
                return create_error("Multiply operation requires two operands");
            }
            return create_success(multiply(operation.a, operation.b.value()));

        case OperationType::Divide:
            if (!operation.b.has_value()) {
                return create_error("Divide operation requires two operands");
            }
            return divide(operation.a, operation.b.value());

        case OperationType::Power:
            if (!operation.b.has_value()) {
                return create_error("Power operation requires two operands");
            }
            return power(operation.a, operation.b.value());

        case OperationType::Sqrt:
            return sqrt(operation.a);

        case OperationType::Factorial:
            if (operation.a < 0 || operation.a != std::floor(operation.a)) {
                return create_error("Factorial requires a non-negative integer");
            }
            return factorial(static_cast<uint32_t>(operation.a));

        default:
            return create_error("Unknown operation type");
    }
}

std::vector<Calculator::CalculationResult> Calculator::calculate_batch(
    const std::vector<Operation>& operations) const {

    std::vector<CalculationResult> results;
    results.reserve(operations.size());

    for (const auto& op : operations) {
        results.push_back(calculate(op));
    }

    return results;
}

// Component metadata - simplified
Calculator::ComponentInfo Calculator::get_calculator_info() const {
    return ComponentInfo{
        .name = "C++ Calculator Component",
        .version = "1.0.0",
        .supported_operations = {
            "add", "subtract", "multiply", "divide",
            "power", "sqrt", "factorial"
        },
        .precision = "IEEE 754 double precision",
        .max_factorial = 20
    };
}

// Mathematical constants - simplified
double Calculator::get_pi() const {
    return 3.141592653589793;
}

double Calculator::get_e() const {
    return 2.718281828459045;
}

// Private helper methods
Calculator::CalculationResult Calculator::create_error(const std::string& message) const {
    return CalculationResult(message);
}

Calculator::CalculationResult Calculator::create_success(double value) const {
    return CalculationResult(value);
}

bool Calculator::validate_inputs(double a, double b) const {
    // Simple validation - avoid math_utils
    return !isnan(a) && !isnan(b) && isfinite(a) && isfinite(b);
}

std::string Calculator::operation_to_string(OperationType op) const {
    switch (op) {
        case OperationType::Add: return "add";
        case OperationType::Subtract: return "subtract";
        case OperationType::Multiply: return "multiply";
        case OperationType::Divide: return "divide";
        case OperationType::Power: return "power";
        case OperationType::Sqrt: return "sqrt";
        case OperationType::Factorial: return "factorial";
        default: return "unknown";
    }
}

} // namespace calculator

// WIT interface implementation - must match generated binding signatures
// Include generated binding header for proper types
#include "calculator.h"

extern "C" {

// Global calculator instance
static calculator::Calculator calc;

// Helper function to convert C++ result to WIT binding result structure
void fill_calculation_result(const calculator::Calculator::CalculationResult& cpp_result,
                            exports_example_calculator_calc_calculation_result_t* wit_result) {
    wit_result->success = cpp_result.success;

    if (cpp_result.success) {
        wit_result->value.is_some = true;
        wit_result->value.val = cpp_result.result.value();
        wit_result->error.is_some = false;
    } else {
        wit_result->value.is_some = false;
        wit_result->error.is_some = true;
        calculator_string_dup(&wit_result->error.val, cpp_result.error.value().c_str());
    }
}

// WIT interface implementations - exact names expected by generated bindings
double exports_example_calculator_calc_add(double a, double b) {
    return calc.add(a, b);
}

double exports_example_calculator_calc_subtract(double a, double b) {
    return calc.subtract(a, b);
}

double exports_example_calculator_calc_multiply(double a, double b) {
    return calc.multiply(a, b);
}

void exports_example_calculator_calc_divide(double a, double b, exports_example_calculator_calc_calculation_result_t *ret) {
    auto result = calc.divide(a, b);
    fill_calculation_result(result, ret);
}

void exports_example_calculator_calc_power(double base, double exponent, exports_example_calculator_calc_calculation_result_t *ret) {
    auto result = calc.power(base, exponent);
    fill_calculation_result(result, ret);
}

void exports_example_calculator_calc_sqrt(double value, exports_example_calculator_calc_calculation_result_t *ret) {
    auto result = calc.sqrt(value);
    fill_calculation_result(result, ret);
}

void exports_example_calculator_calc_factorial(uint32_t n, exports_example_calculator_calc_calculation_result_t *ret) {
    auto result = calc.factorial(n);
    fill_calculation_result(result, ret);
}

void exports_example_calculator_calc_calculate(exports_example_calculator_calc_operation_t *operation, exports_example_calculator_calc_calculation_result_t *ret) {
    // Convert WIT operation to C++ operation
    calculator::Calculator::Operation cpp_op;

    // Convert operation type
    switch (operation->op.tag) {
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_ADD:
            cpp_op.op = calculator::Calculator::OperationType::Add;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_SUBTRACT:
            cpp_op.op = calculator::Calculator::OperationType::Subtract;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_MULTIPLY:
            cpp_op.op = calculator::Calculator::OperationType::Multiply;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_DIVIDE:
            cpp_op.op = calculator::Calculator::OperationType::Divide;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_POWER:
            cpp_op.op = calculator::Calculator::OperationType::Power;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_SQRT:
            cpp_op.op = calculator::Calculator::OperationType::Sqrt;
            break;
        case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_FACTORIAL:
            cpp_op.op = calculator::Calculator::OperationType::Factorial;
            break;
        default:
            // Return error for unknown operation
            ret->success = false;
            ret->error.is_some = true;
            calculator_string_dup(&ret->error.val, "Unknown operation type");
            ret->value.is_some = false;
            return;
    }

    cpp_op.a = operation->a;
    if (operation->b.is_some) {
        cpp_op.b = operation->b.val;
    }

    auto result = calc.calculate(cpp_op);
    fill_calculation_result(result, ret);
}

void exports_example_calculator_calc_calculate_batch(exports_example_calculator_calc_list_operation_t *operations, exports_example_calculator_calc_list_calculation_result_t *ret) {
    // Convert WIT operations list to C++ vector
    std::vector<calculator::Calculator::Operation> cpp_operations;
    cpp_operations.reserve(operations->len);

    for (size_t i = 0; i < operations->len; i++) {
        exports_example_calculator_calc_operation_t* wit_op = &operations->ptr[i];
        calculator::Calculator::Operation cpp_op;

        // Convert operation type (same logic as single calculate)
        switch (wit_op->op.tag) {
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_ADD:
                cpp_op.op = calculator::Calculator::OperationType::Add;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_SUBTRACT:
                cpp_op.op = calculator::Calculator::OperationType::Subtract;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_MULTIPLY:
                cpp_op.op = calculator::Calculator::OperationType::Multiply;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_DIVIDE:
                cpp_op.op = calculator::Calculator::OperationType::Divide;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_POWER:
                cpp_op.op = calculator::Calculator::OperationType::Power;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_SQRT:
                cpp_op.op = calculator::Calculator::OperationType::Sqrt;
                break;
            case EXPORTS_EXAMPLE_CALCULATOR_CALC_OPERATION_TYPE_FACTORIAL:
                cpp_op.op = calculator::Calculator::OperationType::Factorial;
                break;
            default:
                cpp_op.op = calculator::Calculator::OperationType::Add; // Default fallback
                break;
        }

        cpp_op.a = wit_op->a;
        if (wit_op->b.is_some) {
            cpp_op.b = wit_op->b.val;
        }

        cpp_operations.push_back(cpp_op);
    }

    // Execute batch calculation
    auto cpp_results = calc.calculate_batch(cpp_operations);

    // Convert results back to WIT format
    ret->len = cpp_results.size();
    ret->ptr = (exports_example_calculator_calc_calculation_result_t*)malloc(
        cpp_results.size() * sizeof(exports_example_calculator_calc_calculation_result_t));

    for (size_t i = 0; i < cpp_results.size(); i++) {
        fill_calculation_result(cpp_results[i], &ret->ptr[i]);
    }
}

void exports_example_calculator_calc_get_calculator_info(exports_example_calculator_calc_component_info_t *ret) {
    auto info = calc.get_calculator_info();

    // Convert strings
    calculator_string_dup(&ret->name, info.name.c_str());
    calculator_string_dup(&ret->version, info.version.c_str());
    calculator_string_dup(&ret->precision, info.precision.c_str());
    ret->max_factorial = info.max_factorial;

    // Convert supported operations list
    ret->supported_operations.len = info.supported_operations.size();
    ret->supported_operations.ptr = (calculator_string_t*)malloc(
        info.supported_operations.size() * sizeof(calculator_string_t));

    for (size_t i = 0; i < info.supported_operations.size(); i++) {
        calculator_string_dup(&ret->supported_operations.ptr[i], info.supported_operations[i].c_str());
    }
}

double exports_example_calculator_calc_get_pi(void) {
    return calc.get_pi();
}

double exports_example_calculator_calc_get_e(void) {
    return calc.get_e();
}

} // extern "C"
