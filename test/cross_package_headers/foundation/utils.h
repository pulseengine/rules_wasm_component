#ifndef FOUNDATION_UTILS_H
#define FOUNDATION_UTILS_H

// Cross-package header inclusion (quoted includes)
#include "foundation/types.h"

// External dependencies from Bazel Central Registry - testing all include patterns
// Pattern 1: Quoted includes for external libraries (typical Bazel style)
// Note: using fmt through spdlog to avoid conflicts
// #include "fmt/format.h"                     // Modern formatting library
#include "nlohmann/json.hpp"                // JSON parsing/generation
#include "absl/strings/string_view.h"       // Google's string utilities
#include "absl/strings/str_cat.h"           // String concatenation
#include "absl/strings/str_split.h"         // String splitting
#include "absl/strings/str_join.h"          // String joining
#include "absl/container/flat_hash_map.h"   // High-performance hash map
#include "absl/time/time.h"                 // Time utilities
#include "absl/time/clock.h"                // Clock utilities
#include "spdlog/spdlog.h"                  // Fast logging

// Pattern 2: Angle bracket includes for standard library (system headers)
#include <string>
#include <vector>
#include <memory>
#include <iostream>
#include <stdexcept>
#include <limits>
#include <sstream>

// Pattern 3: Mixed includes (some external libraries prefer angle brackets)
// Note: catch2 not available in this build setup, but pattern demonstrated

// Pattern 4: C compatibility headers (C++ wrappers for C standard library)
#include <cmath>        // C++ math functions
#include <cstdio>       // C++ stdio functions
#include <cstring>      // C++ string functions
#include <cstdlib>      // C++ stdlib functions

// Pattern 5: Feature test and conditional includes (C++17/20 features)
#ifdef __has_include
    #if __has_include(<version>)
        #include <version>  // C++20 feature test header
    #endif
    #if __has_include(<source_location>)
        #include <source_location>  // C++20 source location
    #endif
#endif

// Pattern 6: Template and metaprogramming headers
#include <type_traits>  // Template metaprogramming
#include <utility>      // std::move, std::forward, etc.

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

// Test class demonstrating stacked includes and deep header dependencies
class IncludePatternTester {
public:
    // Test stacked includes: spdlog includes fmt, which includes system headers
    static void test_stacked_includes_spdlog_fmt();

    // Test nested external dependencies: nlohmann includes standard library headers
    static void test_nested_json_dependencies();

    // Test Abseil's internal header dependencies (absl includes many sub-headers)
    static void test_abseil_header_stack();

    // Test Catch2's macro system (heavy header-only framework)
    static void test_catch2_macro_system();

    // Comprehensive test mixing all include patterns
    static nlohmann::json run_comprehensive_include_test();
private:
    // Test deep stack: external -> external -> standard library
    static std::string test_deep_header_stack();
};

// Advanced include pattern tester based on cppreference.com research
class AdvancedIncludePatternTester {
public:
    // Test C compatibility headers (cmath, cstdio, cstring, cstdlib)
    static void test_c_compatibility_headers();

    // Test conditional includes with __has_include feature detection
    static void test_conditional_includes_has_include();

    // Test template metaprogramming headers propagation
    static void test_template_metaprogramming_headers();

    // Test macro-expanded includes (if any libraries use them)
    static void test_macro_expanded_includes();

    // Test header guards vs pragma once behavior
    static void test_header_guard_behavior();

    // Test recursive inclusion depth and limits
    static void test_recursive_inclusion_patterns();

    // Test search path priority: quoted vs angle bracket behavior
    static void test_search_path_priority();

    // Test all C++ standard library header categories
    static void test_standard_library_categories();

    // Comprehensive advanced include pattern test
    static nlohmann::json run_advanced_include_test();
};

} // namespace utils
} // namespace foundation

#endif // FOUNDATION_UTILS_H
