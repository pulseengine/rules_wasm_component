#include "foundation/types.h"

namespace foundation {

Point create_point(int32_t x, int32_t y) {
    return Point{x, y};
}

Rectangle create_rectangle(const Point& tl, const Point& br) {
    return Rectangle{tl, br};
}

int32_t calculate_area(const Rectangle& rect) {
    int32_t width = rect.bottom_right.x - rect.top_left.x;
    int32_t height = rect.bottom_right.y - rect.top_left.y;
    return width * height;
}

} // namespace foundation
