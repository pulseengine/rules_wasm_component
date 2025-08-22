#ifndef FOUNDATION_UTILS_H
#define FOUNDATION_UTILS_H

#include "foundation/types.h"

// External dependencies from Bazel Central Registry
#include "fmt/format.h"                     // Modern formatting library
#include "nlohmann/json.hpp"                // JSON parsing/generation
#include "absl/strings/string_view.h"       // Google's string utilities
#include "absl/strings/str_cat.h"           // String concatenation
#include "absl/strings/str_split.h"         // String splitting
#include "absl/container/flat_hash_map.h"   // High-performance hash map
#include "absl/time/time.h"                 // Time utilities
#include "absl/time/clock.h"                // Clock utilities
#include "spdlog/spdlog.h"                  // Fast logging

#include <string>
#include <vector>

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

// Real-world Abseil utilities demonstrating compiled library usage
class GeometryCache {
public:
    // High-performance caching using Abseil containers
    void cache_rectangle(absl::string_view id, const Rectangle& rect);
    Rectangle* get_cached_rectangle(absl::string_view id);
    std::vector<std::string> list_cached_ids() const;
    
    // String processing with Abseil utilities
    std::vector<Point> parse_points_from_csv(absl::string_view csv_data);
    std::string format_points_as_summary(const std::vector<Point>& points);
    
    // Time-based functionality
    void log_operation_with_timestamp(absl::string_view operation, const Point& point);
    absl::Duration get_cache_age(absl::string_view id) const;
    
private:
    absl::flat_hash_map<std::string, Rectangle> rectangle_cache_;
    absl::flat_hash_map<std::string, absl::Time> cache_timestamps_;
};

// Structured logging with spdlog (demonstrates both header-only and compiled patterns)
void setup_logging(const std::string& log_level = "info");
void log_geometry_operation(const std::string& operation, const Point& point);
void log_performance_metrics(const std::string& operation, absl::Duration duration);

// Advanced string processing combining multiple libraries
class TextProcessor {
public:
    // Parse structured text using Abseil string utilities
    static std::vector<Point> extract_coordinates_from_text(absl::string_view text);
    
    // Format output using fmt with custom styling
    static std::string format_geometry_report(
        const std::vector<Rectangle>& rectangles,
        absl::string_view title = "Geometry Report"
    );
    
    // JSON batch processing
    static nlohmann::json create_batch_analysis(const std::vector<Rectangle>& rectangles);
};

} // namespace utils
} // namespace foundation

#endif // FOUNDATION_UTILS_H
