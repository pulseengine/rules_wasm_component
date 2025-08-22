// Consumer component implementation
// This file tests cross-package header inclusion

// THE CRITICAL TEST: These includes should work if headers are staged correctly
#include "foundation/types.h"   // Cross-package header inclusion
#include "foundation/utils.h"   // Cross-package header with nested dependencies

#include <string>

// Comprehensive test function demonstrating cross-package headers + external dependencies
void test_cross_package_headers_with_external_deps() {
    // Test basic point creation from cross-package header
    foundation::Point p1 = foundation::create_point(10, 20);
    foundation::Point p2 = foundation::create_point(50, 60);

    // Test rectangle creation from cross-package header
    foundation::Rectangle rect = foundation::create_rectangle(p1, p2);

    // Test validation utilities from cross-package header
    bool valid = foundation::utils::is_valid_rectangle(rect);

    // Test calculation utilities from cross-package header
    int32_t area = foundation::calculate_area(rect);
    foundation::Point center = foundation::utils::get_rectangle_center(rect);

    // Test modern string formatting with fmt library (via cross-package headers)
    std::string point_str = foundation::utils::point_to_string(p1);
    std::string rect_str = foundation::utils::rectangle_to_string(rect);

    // Test JSON serialization with nlohmann/json (via cross-package headers)
    nlohmann::json point_json = foundation::utils::point_to_json(p1);
    nlohmann::json rect_json = foundation::utils::rectangle_to_json(rect);

    // Test configuration utilities
    std::string config_json = foundation::utils::get_config_as_json();
    bool config_loaded = foundation::utils::load_config_from_json(config_json);

    // Test JSON round-trip serialization
    foundation::Point restored_point = foundation::utils::point_from_json(point_json);
    foundation::Rectangle restored_rect = foundation::utils::rectangle_from_json(rect_json);

    // If we get here without compilation errors, cross-package headers + external dependencies work!
}
