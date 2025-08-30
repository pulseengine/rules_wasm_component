#include "math_utils.h"
#include <cmath>
#include <limits>

namespace math_utils {

bool MathUtils::is_valid_number(double n) {
    return !std::isnan(n) && !std::isinf(n);
}

bool MathUtils::is_finite_number(double n) {
    return std::isfinite(n);
}

std::optional<double> MathUtils::safe_divide(double a, double b) {
    if (!is_valid_number(a) || !is_valid_number(b)) {
        return std::nullopt;
    }

    if (approximately_equal(b, 0.0)) {
        return std::nullopt;  // Division by zero
    }

    double result = a / b;
    if (!is_finite_number(result)) {
        return std::nullopt;
    }

    return round_to_precision(result);
}

std::optional<double> MathUtils::safe_power(double base, double exponent) {
    if (!is_valid_number(base) || !is_valid_number(exponent)) {
        return std::nullopt;
    }

    // Handle special cases
    if (approximately_equal(base, 0.0) && exponent < 0) {
        return std::nullopt;  // 0^negative is undefined
    }

    if (base < 0 && std::floor(exponent) != exponent) {
        return std::nullopt;  // Negative base with non-integer exponent
    }

    double result = std::pow(base, exponent);
    if (!is_finite_number(result)) {
        return std::nullopt;
    }

    return round_to_precision(result);
}

std::optional<double> MathUtils::safe_sqrt(double value) {
    if (!is_valid_number(value)) {
        return std::nullopt;
    }

    if (value < 0) {
        return std::nullopt;  // Square root of negative number
    }

    double result = std::sqrt(value);
    return round_to_precision(result);
}

std::optional<uint64_t> MathUtils::safe_factorial(uint32_t n) {
    if (n > MAX_FACTORIAL) {
        return std::nullopt;  // Factorial too large
    }

    if (n == 0 || n == 1) {
        return 1;
    }

    uint64_t result = 1;
    for (uint32_t i = 2; i <= n; ++i) {
        // Check for overflow
        if (result > std::numeric_limits<uint64_t>::max() / i) {
            return std::nullopt;
        }
        result *= i;
    }

    return result;
}

double MathUtils::round_to_precision(double value, int decimal_places) {
    if (!is_finite_number(value)) {
        return value;
    }

    double multiplier = std::pow(10.0, decimal_places);
    return std::round(value * multiplier) / multiplier;
}

bool MathUtils::approximately_equal(double a, double b, double epsilon) {
    return std::abs(a - b) < epsilon;
}

double MathUtils::degrees_to_radians(double degrees) {
    return degrees * PI / 180.0;
}

double MathUtils::radians_to_degrees(double radians) {
    return radians * 180.0 / PI;
}

// Template specialization for batch operations
template<>
std::vector<std::optional<double>> MathUtils::batch_operation<std::function<std::optional<double>(double)>>(
    const std::vector<double>& values,
    std::function<std::optional<double>(double)> operation) {

    std::vector<std::optional<double>> results;
    results.reserve(values.size());

    for (double value : values) {
        results.push_back(operation(value));
    }

    return results;
}

} // namespace math_utils
