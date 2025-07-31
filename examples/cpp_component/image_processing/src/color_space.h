#pragma once

#include "simd_utils.h"
#include <cstdint>
#include <vector>

namespace color_space {

/**
 * Color space conversion utilities with SIMD acceleration
 *
 * Supports conversion between RGB, HSV, HSL, YUV, and grayscale color spaces
 * with high-performance SIMD implementations where possible.
 */

// Color format enumeration
enum class ColorFormat {
    RGB,
    RGBA,
    BGR,
    BGRA,
    GRAYSCALE,
    HSV,
    HSL,
    YUV420,
    YUV444
};

// Color space conversion result
struct ConversionResult {
    bool success;
    std::vector<uint8_t> data;
    uint32_t width;
    uint32_t height;
    ColorFormat format;
    std::string error_message;
};

// Color space converter class
class ColorSpaceConverter {
public:
    ColorSpaceConverter();
    ~ColorSpaceConverter();

    // Main conversion function
    ConversionResult convert(const uint8_t* src_data, uint32_t width, uint32_t height,
                           ColorFormat src_format, ColorFormat dst_format);

    // Specific conversion functions with SIMD acceleration

    // RGB conversions
    bool rgb_to_rgba(const uint8_t* rgb, uint8_t* rgba, size_t pixel_count, uint8_t alpha = 255);
    bool rgba_to_rgb(const uint8_t* rgba, uint8_t* rgb, size_t pixel_count);
    bool rgb_to_bgr(const uint8_t* rgb, uint8_t* bgr, size_t pixel_count);
    bool rgba_to_bgra(const uint8_t* rgba, uint8_t* bgra, size_t pixel_count);

    // Grayscale conversions
    bool rgb_to_grayscale(const uint8_t* rgb, uint8_t* gray, size_t pixel_count);
    bool rgba_to_grayscale(const uint8_t* rgba, uint8_t* gray, size_t pixel_count);
    bool grayscale_to_rgb(const uint8_t* gray, uint8_t* rgb, size_t pixel_count);
    bool grayscale_to_rgba(const uint8_t* gray, uint8_t* rgba, size_t pixel_count, uint8_t alpha = 255);

    // HSV conversions
    bool rgb_to_hsv(const uint8_t* rgb, uint8_t* hsv, size_t pixel_count);
    bool hsv_to_rgb(const uint8_t* hsv, uint8_t* rgb, size_t pixel_count);
    bool rgba_to_hsv(const uint8_t* rgba, uint8_t* hsv, size_t pixel_count);
    bool hsv_to_rgba(const uint8_t* hsv, uint8_t* rgba, size_t pixel_count, uint8_t alpha = 255);

    // HSL conversions
    bool rgb_to_hsl(const uint8_t* rgb, uint8_t* hsl, size_t pixel_count);
    bool hsl_to_rgb(const uint8_t* hsl, uint8_t* rgb, size_t pixel_count);

    // YUV conversions
    bool rgb_to_yuv444(const uint8_t* rgb, uint8_t* yuv, size_t pixel_count);
    bool yuv444_to_rgb(const uint8_t* yuv, uint8_t* rgb, size_t pixel_count);
    bool rgb_to_yuv420(const uint8_t* rgb, uint8_t* y, uint8_t* u, uint8_t* v,
                      uint32_t width, uint32_t height);
    bool yuv420_to_rgb(const uint8_t* y, const uint8_t* u, const uint8_t* v,
                      uint8_t* rgb, uint32_t width, uint32_t height);

    // Color space information
    static int get_channels_per_pixel(ColorFormat format);
    static int get_bytes_per_pixel(ColorFormat format);
    static bool is_packed_format(ColorFormat format);
    static bool has_alpha_channel(ColorFormat format);
    static const char* format_to_string(ColorFormat format);
    static ColorFormat string_to_format(const char* format_str);

    // Performance settings
    void enable_simd(bool enable) { use_simd_ = enable; }
    bool is_simd_enabled() const { return use_simd_; }

    // Statistics
    struct ConversionStats {
        uint64_t total_conversions;
        uint64_t total_pixels_processed;
        double total_time_ms;
        double average_megapixels_per_second;
        bool simd_acceleration_used;
    };

    ConversionStats get_stats() const { return stats_; }
    void reset_stats() { stats_ = {}; }

private:
    bool use_simd_;
    ConversionStats stats_;
    simd_utils::SIMDMemoryPool memory_pool_;

    // Helper functions
    void update_stats(size_t pixel_count, double time_ms);
    bool validate_inputs(const uint8_t* src, uint8_t* dst, size_t pixel_count,
                        ColorFormat src_format, ColorFormat dst_format);

    // SIMD-optimized helper functions
    void simd_rgb_to_hsv_single(uint8_t r, uint8_t g, uint8_t b,
                               uint8_t& h, uint8_t& s, uint8_t& v);
    void simd_hsv_to_rgb_single(uint8_t h, uint8_t s, uint8_t v,
                               uint8_t& r, uint8_t& g, uint8_t& b);
    void simd_rgb_to_hsl_single(uint8_t r, uint8_t g, uint8_t b,
                               uint8_t& h, uint8_t& s, uint8_t& l);
    void simd_hsl_to_rgb_single(uint8_t h, uint8_t s, uint8_t l,
                               uint8_t& r, uint8_t& g, uint8_t& b);
};

// Utility functions for color manipulation

// Color space analysis
struct ColorDistribution {
    uint32_t histogram_r[256];
    uint32_t histogram_g[256];
    uint32_t histogram_b[256];
    uint32_t histogram_h[360];  // Hue histogram (degrees)
    uint32_t histogram_s[256];  // Saturation histogram
    uint32_t histogram_v[256];  // Value/Brightness histogram

    double mean_r, mean_g, mean_b;
    double mean_h, mean_s, mean_v;
    double std_dev_r, std_dev_g, std_dev_b;

    uint32_t dominant_color_rgb;
    uint32_t total_pixels;
};

// Analyze color distribution in an image
ColorDistribution analyze_color_distribution(const uint8_t* rgb_data, size_t pixel_count);

// Color correction and adjustment functions

// Gamma correction
bool apply_gamma_correction(const uint8_t* src, uint8_t* dst, size_t pixel_count,
                           int channels, float gamma);

// Brightness and contrast adjustment
bool adjust_brightness_contrast(const uint8_t* src, uint8_t* dst, size_t pixel_count,
                               int channels, float brightness, float contrast);

// Hue and saturation adjustment
bool adjust_hue_saturation(const uint8_t* rgb, uint8_t* output, size_t pixel_count,
                          float hue_shift_degrees, float saturation_multiplier);

// White balance correction
struct WhiteBalanceParams {
    float temperature;    // Color temperature in Kelvin (2000-12000)
    float tint;          // Green-magenta tint (-1.0 to 1.0)
    float red_gain;      // Red channel multiplier
    float green_gain;    // Green channel multiplier
    float blue_gain;     // Blue channel multiplier
};

bool apply_white_balance(const uint8_t* rgb, uint8_t* output, size_t pixel_count,
                        const WhiteBalanceParams& params);

// Auto white balance using gray world assumption
WhiteBalanceParams calculate_auto_white_balance(const uint8_t* rgb, size_t pixel_count);

// Color space conversion lookup tables (for performance)
class ColorLookupTable {
public:
    ColorLookupTable();

    // Pre-computed lookup tables for fast conversion
    void build_gamma_table(float gamma);
    void build_rgb_to_yuv_table();
    void build_yuv_to_rgb_table();

    // Use lookup tables for conversion
    bool gamma_correct_lut(const uint8_t* src, uint8_t* dst, size_t pixel_count, int channels);
    bool rgb_to_yuv_lut(const uint8_t* rgb, uint8_t* yuv, size_t pixel_count);
    bool yuv_to_rgb_lut(const uint8_t* yuv, uint8_t* rgb, size_t pixel_count);

private:
    uint8_t gamma_lut_[256];
    int16_t rgb_to_y_lut_[256];
    int16_t rgb_to_u_lut_[256];
    int16_t rgb_to_v_lut_[256];
    uint8_t yuv_to_rgb_lut_[256][3];
    bool tables_built_;
};

// Advanced color space operations

// Color channel extraction and manipulation
bool extract_channel(const uint8_t* src, uint8_t* dst, size_t pixel_count,
                    int src_channels, int channel_index);

bool merge_channels(const uint8_t* r, const uint8_t* g, const uint8_t* b,
                   uint8_t* rgb, size_t pixel_count);

bool merge_channels_rgba(const uint8_t* r, const uint8_t* g, const uint8_t* b, const uint8_t* a,
                        uint8_t* rgba, size_t pixel_count);

// Color space interpolation for gradual transitions
bool interpolate_color_spaces(const uint8_t* src1, const uint8_t* src2, uint8_t* dst,
                             size_t pixel_count, int channels, float factor);

// Color palette operations
struct ColorPalette {
    std::vector<uint32_t> colors;  // RGB colors as 32-bit values
    std::vector<uint32_t> counts;  // Frequency of each color
    size_t total_pixels;
};

// Extract dominant colors using K-means clustering
ColorPalette extract_color_palette(const uint8_t* rgb, size_t pixel_count, int num_colors = 16);

// Quantize image to palette
bool quantize_to_palette(const uint8_t* rgb, uint8_t* output, size_t pixel_count,
                        const ColorPalette& palette);

// Dithering for color quantization
bool floyd_steinberg_dither(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                           int channels, const ColorPalette& palette);

// Color difference calculation (Delta E)
float calculate_color_difference_rgb(uint8_t r1, uint8_t g1, uint8_t b1,
                                    uint8_t r2, uint8_t g2, uint8_t b2);

float calculate_color_difference_lab(const uint8_t* lab1, const uint8_t* lab2);

// LAB color space conversion (CIE L*a*b*)
bool rgb_to_lab(const uint8_t* rgb, uint8_t* lab, size_t pixel_count);
bool lab_to_rgb(const uint8_t* lab, uint8_t* rgb, size_t pixel_count);

} // namespace color_space
