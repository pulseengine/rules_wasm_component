#ifndef FOUNDATION_TYPES_H
#define FOUNDATION_TYPES_H

#include <stdint.h>
#include <stddef.h>

// Foundation types for cross-package testing
namespace foundation {

struct Point {
    int32_t x;
    int32_t y;
};

struct Rectangle {
    Point top_left;
    Point bottom_right;
};

// Test function declarations
Point create_point(int32_t x, int32_t y);
Rectangle create_rectangle(const Point& tl, const Point& br);
int32_t calculate_area(const Rectangle& rect);

} // namespace foundation

#endif // FOUNDATION_TYPES_H
