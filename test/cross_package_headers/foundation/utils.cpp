#include "foundation/utils.h"

namespace foundation {
namespace utils {

bool is_valid_point(const Point& p) {
    // Simple validation - check for reasonable coordinate ranges
    return p.x >= -10000 && p.x <= 10000 && p.y >= -10000 && p.y <= 10000;
}

bool is_valid_rectangle(const Rectangle& rect) {
    return is_valid_point(rect.top_left) && 
           is_valid_point(rect.bottom_right) &&
           rect.bottom_right.x > rect.top_left.x &&
           rect.bottom_right.y > rect.top_left.y;
}

Point get_rectangle_center(const Rectangle& rect) {
    int32_t center_x = (rect.top_left.x + rect.bottom_right.x) / 2;
    int32_t center_y = (rect.top_left.y + rect.bottom_right.y) / 2;
    return create_point(center_x, center_y);
}

// Modern string formatting using fmt library
std::string point_to_string(const Point& p) {
    return fmt::format("Point({}, {})", p.x, p.y);
}

std::string rectangle_to_string(const Rectangle& rect) {
    return fmt::format("Rectangle(({},{}) -> ({},{}))", 
                      rect.top_left.x, rect.top_left.y,
                      rect.bottom_right.x, rect.bottom_right.y);
}

// JSON serialization using nlohmann/json
nlohmann::json point_to_json(const Point& p) {
    return nlohmann::json{
        {"x", p.x},
        {"y", p.y},
        {"type", "point"}
    };
}

nlohmann::json rectangle_to_json(const Rectangle& rect) {
    return nlohmann::json{
        {"top_left", point_to_json(rect.top_left)},
        {"bottom_right", point_to_json(rect.bottom_right)},
        {"type", "rectangle"},
        {"area", calculate_area(rect)},
        {"center", point_to_json(get_rectangle_center(rect))}
    };
}

Point point_from_json(const nlohmann::json& j) {
    return create_point(
        j.at("x").get<int32_t>(),
        j.at("y").get<int32_t>()
    );
}

Rectangle rectangle_from_json(const nlohmann::json& j) {
    Point tl = point_from_json(j.at("top_left"));
    Point br = point_from_json(j.at("bottom_right"));
    return create_rectangle(tl, br);
}

// Configuration utilities demonstrating external library integration
std::string get_config_as_json() {
    nlohmann::json config = {
        {"name", "Foundation Graphics Library"},
        {"version", "1.0.0"},
        {"capabilities", {
            {"points", true},
            {"rectangles", true},
            {"json_support", true},
            {"modern_formatting", true}
        }},
        {"limits", {
            {"max_coordinate", 10000},
            {"min_coordinate", -10000}
        }},
        {"external_dependencies", {
            {"fmt", "11.0.2"},
            {"nlohmann_json", "3.11.3"}
        }}
    };
    
    return config.dump(2);  // Pretty-printed JSON
}

bool load_config_from_json(const std::string& json_str) {
    try {
        auto config = nlohmann::json::parse(json_str);
        
        // Validate required fields
        if (!config.contains("name") || !config.contains("version")) {
            return false;
        }
        
        // Could update internal configuration here
        return true;
    } catch (const nlohmann::json::exception& e) {
        return false;
    }
}

} // namespace utils
} // namespace foundation