// Test to verify cross-package header inclusion works
#include "foundation/types.h"
#include "foundation/utils.h"

#include <cassert>
#include <iostream>

int main() {
    std::cout << "Testing cross-package header inclusion...\n";

    // Test 1: Basic point creation
    foundation::Point p1 = foundation::create_point(10, 20);
    assert(p1.x == 10);
    assert(p1.y == 20);
    std::cout << "✓ Point creation works\n";

    // Test 2: Rectangle creation
    foundation::Point p2 = foundation::create_point(50, 60);
    foundation::Rectangle rect = foundation::create_rectangle(p1, p2);
    assert(rect.top_left.x == 10);
    assert(rect.bottom_right.y == 60);
    std::cout << "✓ Rectangle creation works\n";

    // Test 3: Area calculation
    int32_t area = foundation::calculate_area(rect);
    assert(area == 40 * 40); // (50-10) * (60-20) = 40 * 40 = 1600
    assert(area == 1600);
    std::cout << "✓ Area calculation works: " << area << "\n";

    // Test 4: Utility functions
    bool valid = foundation::utils::is_valid_rectangle(rect);
    assert(valid == true);
    std::cout << "✓ Rectangle validation works\n";

    // Test 5: String conversion
    const char* point_str = foundation::utils::point_to_string(p1);
    const char* rect_str = foundation::utils::rectangle_to_string(rect);
    assert(point_str != nullptr);
    assert(rect_str != nullptr);
    std::cout << "✓ String conversion works\n";
    std::cout << "  Point: " << point_str << "\n";
    std::cout << "  Rectangle: " << rect_str << "\n";

    // Test 6: Center calculation
    foundation::Point center = foundation::utils::get_rectangle_center(rect);
    assert(center.x == 30); // (10 + 50) / 2 = 30
    assert(center.y == 40); // (20 + 60) / 2 = 40
    std::cout << "✓ Center calculation works: " << foundation::utils::point_to_string(center) << "\n";

    std::cout << "\n🎉 All cross-package header tests passed!\n";
    std::cout << "Headers are properly staged and include paths work correctly.\n";

    return 0;
}
