#ifndef FOUNDATION_UTILS_H
#define FOUNDATION_UTILS_H

#include "foundation/types.h"

// External dependencies from Bazel Central Registry
#include "fmt/format.h"         // Modern formatting library
#include "nlohmann/json.hpp"    // JSON parsing/generation

#include <string>

namespace foundation {
namespace utils {

// Utility functions that depend on types.h
bool is_valid_point(const Point& p);
bool is_valid_rectangle(const Rectangle& rect);
Point get_rectangle_center(const Rectangle& rect);

// Modern string conversion utilities using fmt library
std::string point_to_string(const Point& p);
std::string rectangle_to_string(const Rectangle& rect);

// JSON serialization using nlohmann/json library
nlohmann::json point_to_json(const Point& p);
nlohmann::json rectangle_to_json(const Rectangle& rect);
Point point_from_json(const nlohmann::json& j);
Rectangle rectangle_from_json(const nlohmann::json& j);

// Configuration utilities with JSON support
std::string get_config_as_json();
bool load_config_from_json(const std::string& json_str);

} // namespace utils
} // namespace foundation

#endif // FOUNDATION_UTILS_H
