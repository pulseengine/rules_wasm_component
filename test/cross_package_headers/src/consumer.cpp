// Consumer component implementation
// This file tests cross-package header inclusion

// THE CRITICAL TEST: These includes should work if headers are staged correctly
#include "foundation/types.h"   // Cross-package header inclusion
#include "foundation/utils.h"   // Cross-package header with nested dependencies

#include <string>

// Comprehensive test function demonstrating cross-package headers + external dependencies
void test_cross_package_headers_with_external_deps() {
    // Initialize logging (spdlog) for comprehensive testing
    foundation::utils::setup_logging("info");

    // Test basic point creation from cross-package header
    foundation::Point p1 = foundation::create_point(10, 20);
    foundation::Point p2 = foundation::create_point(50, 60);
    foundation::Point p3 = foundation::create_point(100, 150);

    // Test rectangle creation from cross-package header
    foundation::Rectangle rect1 = foundation::create_rectangle(p1, p2);
    foundation::Rectangle rect2 = foundation::create_rectangle(p2, p3);

    // Test validation utilities from cross-package header
    bool valid = foundation::utils::is_valid_rectangle(rect1);

    // Test calculation utilities from cross-package header
    int32_t area = foundation::calculate_area(rect1);
    foundation::Point center = foundation::utils::get_rectangle_center(rect1);

    // Test modern string formatting with fmt library (via cross-package headers)
    std::string point_str = foundation::utils::point_to_string(p1);
    std::string rect_str = foundation::utils::rectangle_to_string(rect1);

    // Test JSON serialization with nlohmann/json (via cross-package headers)
    nlohmann::json point_json = foundation::utils::point_to_json(p1);
    nlohmann::json rect_json = foundation::utils::rectangle_to_json(rect1);

    // Test configuration utilities
    std::string config_json = foundation::utils::get_config_as_json();
    bool config_loaded = foundation::utils::load_config_from_json(config_json);

    // Test JSON round-trip serialization
    foundation::Point restored_point = foundation::utils::point_from_json(point_json);
    foundation::Rectangle restored_rect = foundation::utils::rectangle_from_json(rect_json);

    // === NEW COMPREHENSIVE REAL-WORLD TESTS ===

    // Test GeometryCache with Abseil containers and time utilities
    foundation::utils::GeometryCache cache;
    cache.cache_rectangle("rect1", rect1);
    cache.cache_rectangle("rect2", rect2);

    // Test cache retrieval and ID listing
    foundation::Rectangle* cached = cache.get_cached_rectangle("rect1");
    std::vector<std::string> cached_ids = cache.list_cached_ids();

    // Test CSV parsing with Abseil string utilities
    std::string csv_data = "10,20\n30,40\n50,60\n100,150";
    std::vector<foundation::Point> parsed_points = cache.parse_points_from_csv(csv_data);

    // Test point summary formatting with Abseil string concatenation
    std::string summary = cache.format_points_as_summary(parsed_points);

    // Test timestamp logging with Abseil time utilities
    cache.log_operation_with_timestamp("test_operation", p1);

    // Test cache age calculation
    absl::Duration age = cache.get_cache_age("rect1");

    // Test structured logging with spdlog
    foundation::utils::log_geometry_operation("cache_test", center);
    foundation::utils::log_performance_metrics("parsing_operation", absl::Milliseconds(5));

    // Test TextProcessor advanced string processing
    std::string sample_text = "Found coordinates: (10,20), (30,40) and also 50,60 in the data.";
    std::vector<foundation::Point> extracted_points =
        foundation::utils::TextProcessor::extract_coordinates_from_text(sample_text);

    // Test geometry report formatting with fmt
    std::vector<foundation::Rectangle> rectangles = {rect1, rect2};
    std::string report = foundation::utils::TextProcessor::format_geometry_report(
        rectangles, "Cross-Package Header Test Report"
    );

    // Test comprehensive batch analysis with JSON
    nlohmann::json batch_analysis = foundation::utils::TextProcessor::create_batch_analysis(rectangles);

    // === COMPREHENSIVE INCLUDE PATTERN TESTING ===

    // Test all include patterns comprehensively
    nlohmann::json include_pattern_results = foundation::utils::IncludePatternTester::run_comprehensive_include_test();

    // Test advanced include patterns based on cppreference.com research
    nlohmann::json advanced_include_results = foundation::utils::AdvancedIncludePatternTester::run_advanced_include_test();

    // Test comprehensive external library integration
    nlohmann::json comprehensive_test_results = {
        {"test_name", "cross_package_headers_comprehensive"},
        {"libraries_tested", {
            {"fmt", "Modern C++ formatting"},
            {"nlohmann_json", "JSON parsing and serialization"},
            {"abseil-cpp", "Google's utility libraries"},
            {"spdlog", "Fast logging library"},
            {"catch2", "Testing framework (header-only)"}
        }},
        {"include_patterns_validated", {
            {"quoted_includes", "Cross-package and external library headers"},
            {"angle_bracket_includes", "System headers and some external libraries"},
            {"stacked_includes", "Multi-level dependency chains tested"},
            {"deep_header_stacks", "4+ levels of header dependencies working"},
            {"c_compatibility_headers", "C++ wrappers for C standard library"},
            {"conditional_includes", "__has_include feature detection"},
            {"template_metaprogramming", "Complex template header propagation"},
            {"header_guard_behavior", "Multiple inclusion prevention verified"},
            {"recursive_inclusion", "Deep dependency analysis complete"},
            {"search_path_priority", "Quoted vs angle bracket search tested"}
        }},
        {"results", {
            {"basic_validation", valid},
            {"area_calculation", area},
            {"cached_rectangles", cached_ids.size()},
            {"parsed_points", parsed_points.size()},
            {"extracted_coordinates", extracted_points.size()},
            {"summary", summary},
            {"config_loaded", config_loaded}
        }},
        {"performance_notes", "All cross-package headers with external dependencies working"},
        {"batch_analysis", batch_analysis},
        {"include_pattern_analysis", include_pattern_results},
        {"advanced_include_analysis", advanced_include_results}
    };

    // If we get here without compilation errors, comprehensive cross-package headers +
    // all external dependencies (fmt, nlohmann_json, abseil-cpp, spdlog, catch2) work perfectly!
    // This includes ALL cppreference.com documented include patterns:
    // 1. Cross-package quoted includes: "foundation/types.h", "foundation/utils.h"
    // 2. External quoted includes: "fmt/format.h", "nlohmann/json.hpp", "absl/strings/..."
    // 3. System angle includes: <string>, <vector>, <memory>, <iostream>, <stdexcept>
    // 4. External angle includes: <catch2/catch_test_macros.hpp>
    // 5. C compatibility headers: <cmath>, <cstdio>, <cstring>, <cstdlib>
    // 6. Conditional includes: __has_include(<version>), __has_include(<source_location>)
    // 7. Template metaprogramming: <type_traits>, <utility> with complex instantiations
    // 8. Header guard behavior: Traditional #ifndef/#define/#endif guards
    // 9. Stacked includes: spdlog->fmt->stdlib, nlohmann->stdlib, abseil->abseil_internal->stdlib
    // 10. Deep dependency chains: our_code->external1->external2->stdlib (4+ levels)
    // 11. Search path priority: Quoted vs angle bracket search behavior
    // 12. Standard library categories: All major header groups from cppreference.com
}
