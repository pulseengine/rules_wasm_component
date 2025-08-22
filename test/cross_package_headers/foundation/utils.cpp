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
            {"nlohmann_json", "3.11.3"},
            {"abseil-cpp", "20250814.0"},
            {"spdlog", "1.12.0"}
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

// GeometryCache implementation demonstrating Abseil containers and time utilities
void GeometryCache::cache_rectangle(absl::string_view id, const Rectangle& rect) {
    std::string key(id);
    rectangle_cache_[key] = rect;
    cache_timestamps_[key] = absl::Now();
    
    spdlog::debug("Cached rectangle '{}': {}", key, rectangle_to_string(rect));
}

Rectangle* GeometryCache::get_cached_rectangle(absl::string_view id) {
    std::string key(id);
    auto it = rectangle_cache_.find(key);
    if (it != rectangle_cache_.end()) {
        spdlog::debug("Cache hit for rectangle '{}'", key);
        return &it->second;
    }
    spdlog::debug("Cache miss for rectangle '{}'", key);
    return nullptr;
}

std::vector<std::string> GeometryCache::list_cached_ids() const {
    std::vector<std::string> ids;
    ids.reserve(rectangle_cache_.size());
    for (const auto& [key, _] : rectangle_cache_) {
        ids.push_back(key);
    }
    return ids;
}

std::vector<Point> GeometryCache::parse_points_from_csv(absl::string_view csv_data) {
    std::vector<Point> points;
    
    // Split by lines first
    std::vector<absl::string_view> lines = absl::StrSplit(csv_data, '\n');
    
    for (absl::string_view line : lines) {
        if (line.empty()) continue;
        
        // Split each line by comma
        std::vector<absl::string_view> coords = absl::StrSplit(line, ',');
        if (coords.size() >= 2) {
            try {
                int32_t x = std::stoi(std::string(coords[0]));
                int32_t y = std::stoi(std::string(coords[1]));
                points.push_back(create_point(x, y));
            } catch (const std::exception& e) {
                spdlog::warn("Failed to parse coordinates from line: '{}'", line);
            }
        }
    }
    
    spdlog::info("Parsed {} points from CSV data", points.size());
    return points;
}

std::string GeometryCache::format_points_as_summary(const std::vector<Point>& points) {
    if (points.empty()) {
        return "No points to summarize";
    }
    
    // Calculate bounding box using Abseil string concatenation
    int32_t min_x = points[0].x, max_x = points[0].x;
    int32_t min_y = points[0].y, max_y = points[0].y;
    
    for (const Point& p : points) {
        min_x = std::min(min_x, p.x);
        max_x = std::max(max_x, p.x);
        min_y = std::min(min_y, p.y);
        max_y = std::max(max_y, p.y);
    }
    
    return absl::StrCat(
        "Point Summary: ", points.size(), " points, ",
        "X range: [", min_x, ", ", max_x, "], ",
        "Y range: [", min_y, ", ", max_y, "], ",
        "Bounding area: ", (max_x - min_x) * (max_y - min_y)
    );
}

void GeometryCache::log_operation_with_timestamp(absl::string_view operation, const Point& point) {
    absl::Time now = absl::Now();
    std::string timestamp = absl::FormatTime("%Y-%m-%d %H:%M:%S %Z", now, absl::UTCTimeZone());
    
    spdlog::info("Operation '{}' on point {} at {}", operation, point_to_string(point), timestamp);
}

absl::Duration GeometryCache::get_cache_age(absl::string_view id) const {
    std::string key(id);
    auto it = cache_timestamps_.find(key);
    if (it != cache_timestamps_.end()) {
        return absl::Now() - it->second;
    }
    return absl::InfiniteDuration();
}

// Structured logging setup with spdlog
void setup_logging(const std::string& log_level) {
    if (log_level == "debug") {
        spdlog::set_level(spdlog::level::debug);
    } else if (log_level == "info") {
        spdlog::set_level(spdlog::level::info);
    } else if (log_level == "warn") {
        spdlog::set_level(spdlog::level::warn);
    } else if (log_level == "error") {
        spdlog::set_level(spdlog::level::err);
    }
    
    spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
    spdlog::info("Logging initialized with level: {}", log_level);
}

void log_geometry_operation(const std::string& operation, const Point& point) {
    spdlog::info("Geometry operation: {} on {}", operation, point_to_string(point));
}

void log_performance_metrics(const std::string& operation, absl::Duration duration) {
    double milliseconds = absl::ToDoubleMilliseconds(duration);
    spdlog::info("Performance: {} completed in {:.2f}ms", operation, milliseconds);
}

// TextProcessor implementation demonstrating advanced string processing
std::vector<Point> TextProcessor::extract_coordinates_from_text(absl::string_view text) {
    std::vector<Point> points;
    
    // Look for patterns like "(x,y)" or "x,y" in the text
    std::vector<absl::string_view> tokens = absl::StrSplit(text, absl::ByAnyChar(" \t\n()[]{}"));
    
    for (absl::string_view token : tokens) {
        if (token.empty()) continue;
        
        // Check if token contains comma-separated coordinates
        if (absl::StrContains(token, ',')) {
            std::vector<absl::string_view> coords = absl::StrSplit(token, ',');
            if (coords.size() == 2) {
                try {
                    int32_t x = std::stoi(std::string(coords[0]));
                    int32_t y = std::stoi(std::string(coords[1]));
                    points.push_back(create_point(x, y));
                } catch (const std::exception& e) {
                    // Skip invalid coordinates
                }
            }
        }
    }
    
    return points;
}

std::string TextProcessor::format_geometry_report(
    const std::vector<Rectangle>& rectangles,
    absl::string_view title
) {
    std::string report = fmt::format("=== {} ===\n", title);
    
    if (rectangles.empty()) {
        report += "No rectangles to report.\n";
        return report;
    }
    
    report += fmt::format("Total rectangles: {}\n\n", rectangles.size());
    
    int64_t total_area = 0;
    for (size_t i = 0; i < rectangles.size(); ++i) {
        const Rectangle& rect = rectangles[i];
        int64_t area = calculate_area(rect);
        total_area += area;
        
        report += fmt::format("Rectangle {}: {} (area: {})\n", 
                             i + 1, rectangle_to_string(rect), area);
    }
    
    report += fmt::format("\nTotal combined area: {}\n", total_area);
    report += fmt::format("Average area: {:.2f}\n", 
                         static_cast<double>(total_area) / rectangles.size());
    
    return report;
}

nlohmann::json TextProcessor::create_batch_analysis(const std::vector<Rectangle>& rectangles) {
    nlohmann::json analysis = {
        {"analysis_type", "batch_geometry"},
        {"timestamp", absl::FormatTime(absl::RFC3339_full, absl::Now(), absl::UTCTimeZone())},
        {"rectangle_count", rectangles.size()},
        {"rectangles", nlohmann::json::array()}
    };
    
    int64_t total_area = 0;
    int64_t min_area = std::numeric_limits<int64_t>::max();
    int64_t max_area = 0;
    
    for (size_t i = 0; i < rectangles.size(); ++i) {
        const Rectangle& rect = rectangles[i];
        int64_t area = calculate_area(rect);
        total_area += area;
        min_area = std::min(min_area, area);
        max_area = std::max(max_area, area);
        
        nlohmann::json rect_data = rectangle_to_json(rect);
        rect_data["index"] = i;
        rect_data["area"] = area;
        
        analysis["rectangles"].push_back(rect_data);
    }
    
    if (!rectangles.empty()) {
        analysis["statistics"] = {
            {"total_area", total_area},
            {"average_area", static_cast<double>(total_area) / rectangles.size()},
            {"min_area", min_area},
            {"max_area", max_area}
        };
    }
    
    analysis["external_libraries_used"] = {
        {"fmt", "11.0.2"},
        {"nlohmann_json", "3.11.3"},
        {"abseil-cpp", "20250814.0"},
        {"spdlog", "1.12.0"}
    };
    
    return analysis;
}

} // namespace utils
} // namespace foundation
