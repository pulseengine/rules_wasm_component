#pragma once

#include <cmath>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace math_utils {

/**
 * Mathematical utility functions for the calculator component
 */
class MathUtils {
public:
    // Constants
    static constexpr double PI = 3.141592653589793;
    static constexpr double E = 2.718281828459045;
    static constexpr uint32_t MAX_FACTORIAL = 20;

    // Error checking
    static bool is_valid_number(double n);
    static bool is_finite_number(double n);

    // Advanced operations
    static std::optional<double> safe_divide(double a, double b);
    static std::optional<double> safe_power(double base, double exponent);
    static std::optional<double> safe_sqrt(double value);
    static std::optional<uint64_t> safe_factorial(uint32_t n);

    // Precision and rounding
    static double round_to_precision(double value, int decimal_places = 15);
    static bool approximately_equal(double a, double b, double epsilon = 1e-10);

    // Batch operations
    template<typename Op>
    static std::vector<std::optional<double>> batch_operation(
        const std::vector<double>& values, Op operation);

    // Mathematical constants and functions
    static double get_pi() { return PI; }
    static double get_e() { return E; }

    // Trigonometric functions (bonus)
    static double degrees_to_radians(double degrees);
    static double radians_to_degrees(double radians);

private:
    static constexpr double EPSILON = 1e-10;
};

/**
 * Result wrapper for operations that can fail
 */
template<typename T>
class Result {
public:
    bool success;
    std::optional<std::string> error;
    std::optional<T> value;

    Result(T val) : success(true), error(std::nullopt), value(val) {}
    Result(const std::string& err) : success(false), error(err), value(std::nullopt) {}

    bool is_ok() const { return success; }
    bool is_err() const { return !success; }

    T unwrap() const {
        // WASI SDK doesn't support exceptions, so we return a default value
        // In production code, you should use unwrap_or() instead of unwrap()
        if (!success) {
            // Return default-constructed value instead of throwing
            return T{};
        }
        return value.value();
    }

    T unwrap_or(T default_value) const {
        return success ? value.value() : default_value;
    }
};

} // namespace math_utils
