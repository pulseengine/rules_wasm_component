#include "calculator_impl.h"
#include <algorithm>
#include <limits>
#include <sstream>

namespace calculator {

// Basic arithmetic operations
double Calculator::add(double a, double b) const {
    if (!math_utils::MathUtils::is_valid_number(a) || !math_utils::MathUtils::is_valid_number(b)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    return math_utils::MathUtils::round_to_precision(a + b);
}

double Calculator::subtract(double a, double b) const {
    if (!math_utils::MathUtils::is_valid_number(a) || !math_utils::MathUtils::is_valid_number(b)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    return math_utils::MathUtils::round_to_precision(a - b);
}

double Calculator::multiply(double a, double b) const {
    if (!math_utils::MathUtils::is_valid_number(a) || !math_utils::MathUtils::is_valid_number(b)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    return math_utils::MathUtils::round_to_precision(a * b);
}

// Operations that can fail
Calculator::CalculationResult Calculator::divide(double a, double b) const {
    if (!validate_inputs(a, b)) {
        return create_error("Invalid input numbers");
    }

    auto result = math_utils::MathUtils::safe_divide(a, b);
    if (!result.has_value()) {
        if (math_utils::MathUtils::approximately_equal(b, 0.0)) {
            return create_error("Division by zero is not allowed");
        }
        return create_error("Division resulted in invalid number");
    }

    return create_success(result.value());
}

Calculator::CalculationResult Calculator::power(double base, double exponent) const {
    if (!validate_inputs(base, exponent)) {
        return create_error("Invalid input numbers");
    }

    auto result = math_utils::MathUtils::safe_power(base, exponent);
    if (!result.has_value()) {
        std::ostringstream oss;
        oss << "Power operation failed: " << base << "^" << exponent;
        return create_error(oss.str());
    }

    return create_success(result.value());
}

Calculator::CalculationResult Calculator::sqrt(double value) const {
    if (!math_utils::MathUtils::is_valid_number(value)) {
        return create_error("Invalid input number");
    }

    auto result = math_utils::MathUtils::safe_sqrt(value);
    if (!result.has_value()) {
        return create_error("Square root of negative number is not supported");
    }

    return create_success(result.value());
}

Calculator::CalculationResult Calculator::factorial(uint32_t n) const {
    auto result = math_utils::MathUtils::safe_factorial(n);
    if (!result.has_value()) {
        std::ostringstream oss;
        oss << "Factorial of " << n << " is too large or not supported";
        return create_error(oss.str());
    }

    return create_success(static_cast<double>(result.value()));
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

// Component metadata
Calculator::ComponentInfo Calculator::get_calculator_info() const {
    return ComponentInfo{
        .name = "C++ Calculator Component",
        .version = "1.0.0",
        .supported_operations = {
            "add", "subtract", "multiply", "divide",
            "power", "sqrt", "factorial"
        },
        .precision = "IEEE 754 double precision (15-17 decimal digits)",
        .max_factorial = math_utils::MathUtils::MAX_FACTORIAL
    };
}

// Mathematical constants
double Calculator::get_pi() const {
    return math_utils::MathUtils::get_pi();
}

double Calculator::get_e() const {
    return math_utils::MathUtils::get_e();
}

// Private helper methods
Calculator::CalculationResult Calculator::create_error(const std::string& message) const {
    return CalculationResult(message);
}

Calculator::CalculationResult Calculator::create_success(double value) const {
    return CalculationResult(value);
}

bool Calculator::validate_inputs(double a, double b) const {
    return math_utils::MathUtils::is_valid_number(a) &&
           math_utils::MathUtils::is_valid_number(b);
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

// WIT interface implementation
// These functions will be called by the generated WIT bindings

extern "C" {

// Global calculator instance
static calculator::Calculator calc;

// WIT interface implementations
double calculator_add(double a, double b) {
    return calc.add(a, b);
}

double calculator_subtract(double a, double b) {
    return calc.subtract(a, b);
}

double calculator_multiply(double a, double b) {
    return calc.multiply(a, b);
}

// For divide operation, we need to return a result struct
// This will be properly implemented once WIT bindings are generated
void calculator_divide(double a, double b, void* result_ptr) {
    auto result = calc.divide(a, b);
    // Implementation depends on generated binding structure
    // For now, this is a placeholder
}

void calculator_power(double base, double exponent, void* result_ptr) {
    auto result = calc.power(base, exponent);
    // Implementation depends on generated binding structure
}

void calculator_sqrt(double value, void* result_ptr) {
    auto result = calc.sqrt(value);
    // Implementation depends on generated binding structure
}

void calculator_factorial(uint32_t n, void* result_ptr) {
    auto result = calc.factorial(n);
    // Implementation depends on generated binding structure
}

double calculator_get_pi() {
    return calc.get_pi();
}

double calculator_get_e() {
    return calc.get_e();
}

} // extern "C"
