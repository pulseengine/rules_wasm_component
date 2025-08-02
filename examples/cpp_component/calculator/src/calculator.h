#pragma once

#include "math_utils.h"
#include <vector>
#include <string>

// Generated WIT bindings will be included here
// #include "calculator_bindings.h"

namespace calculator {

/**
 * Calculator component implementation
 *
 * This class implements the WIT calculator interface and provides
 * comprehensive mathematical operations with proper error handling.
 */
class Calculator {
public:
    Calculator() = default;
    ~Calculator() = default;

    // Basic arithmetic operations
    double add(double a, double b) const;
    double subtract(double a, double b) const;
    double multiply(double a, double b) const;

    // Operations that can fail
    struct CalculationResult {
        bool success;
        std::optional<std::string> error;
        std::optional<double> result;

        CalculationResult(double val)
            : success(true), error(std::nullopt), result(val) {}
        CalculationResult(const std::string& err)
            : success(false), error(err), result(std::nullopt) {}
    };

    CalculationResult divide(double a, double b) const;
    CalculationResult power(double base, double exponent) const;
    CalculationResult sqrt(double value) const;
    CalculationResult factorial(uint32_t n) const;

    // Batch operations
    enum class OperationType {
        Add, Subtract, Multiply, Divide, Power, Sqrt, Factorial
    };

    struct Operation {
        OperationType op;
        double a;
        std::optional<double> b;  // b is optional for unary operations
    };

    CalculationResult calculate(const Operation& operation) const;
    std::vector<CalculationResult> calculate_batch(const std::vector<Operation>& operations) const;

    // Component metadata
    struct ComponentInfo {
        std::string name;
        std::string version;
        std::vector<std::string> supported_operations;
        std::string precision;
        uint32_t max_factorial;
    };

    ComponentInfo get_calculator_info() const;

    // Mathematical constants
    double get_pi() const;
    double get_e() const;

private:
    CalculationResult create_error(const std::string& message) const;
    CalculationResult create_success(double value) const;

    // Operation implementations
    CalculationResult execute_binary_operation(OperationType op, double a, double b) const;
    CalculationResult execute_unary_operation(OperationType op, double a) const;

    // Validation helpers
    bool validate_inputs(double a, double b = 0.0) const;
    std::string operation_to_string(OperationType op) const;
};

} // namespace calculator
