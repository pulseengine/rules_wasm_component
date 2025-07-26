#pragma once

#include "simd_utils.h"
#include "color_space.h"
#include <cstdint>
#include <vector>
#include <memory>

namespace filters {

/**
 * Image filtering operations with SIMD acceleration
 * 
 * Provides a comprehensive set of image filters including blur, sharpen,
 * edge detection, and artistic effects, all optimized with WebAssembly SIMD.
 */

// Filter types
enum class FilterType {
    BOX_BLUR,
    GAUSSIAN_BLUR,
    MOTION_BLUR,
    SHARPEN,
    EDGE_DETECT,
    EMBOSS,
    SOBEL_X,
    SOBEL_Y,
    LAPLACIAN,
    UNSHARP_MASK,
    NOISE_REDUCTION,
    BILATERAL,
    MEDIAN,
    KUWAHARA,
    OIL_PAINTING
};

// Filter parameters
struct FilterParams {
    FilterType type;
    float radius;           // Filter radius/size
    float strength;         // Effect strength (0.0 - 2.0)
    float angle;           // For motion blur (degrees)
    float threshold;       // For edge detection
    float sigma;           // For Gaussian filters
    int kernel_size;       // Custom kernel size
    bool preserve_alpha;   // Keep alpha channel unchanged
    
    FilterParams() : type(FilterType::BOX_BLUR), radius(1.0f), strength(1.0f), 
                    angle(0.0f), threshold(0.5f), sigma(1.0f), kernel_size(3),
                    preserve_alpha(true) {}
};

// Filter result
struct FilterResult {
    bool success;
    std::vector<uint8_t> data;
    uint32_t width;
    uint32_t height;
    int channels;
    std::string error_message;
    double processing_time_ms;
    bool simd_used;
};

// Convolution kernel
struct ConvolutionKernel {
    std::vector<float> data;
    int width;
    int height;
    float bias;
    float scale;
    bool normalize;
    
    ConvolutionKernel(int w, int h) : width(w), height(h), bias(0.0f), 
                                     scale(1.0f), normalize(true) {
        data.resize(w * h, 0.0f);
    }
    
    float& operator()(int x, int y) { return data[y * width + x]; }
    const float& operator()(int x, int y) const { return data[y * width + x]; }
};

// Main filter processor class
class FilterProcessor {
public:
    FilterProcessor();
    ~FilterProcessor();
    
    // Main filter application function
    FilterResult apply_filter(const uint8_t* src_data, uint32_t width, uint32_t height,
                             int channels, const FilterParams& params);
    
    // Specific filter implementations
    
    // Blur filters
    FilterResult box_blur(const uint8_t* src, uint32_t width, uint32_t height,
                         int channels, int radius);
    
    FilterResult gaussian_blur(const uint8_t* src, uint32_t width, uint32_t height,
                              int channels, float radius, float sigma = 0.0f);
    
    FilterResult motion_blur(const uint8_t* src, uint32_t width, uint32_t height,
                            int channels, float length, float angle);
    
    // Sharpening filters
    FilterResult sharpen(const uint8_t* src, uint32_t width, uint32_t height,
                        int channels, float strength);
    
    FilterResult unsharp_mask(const uint8_t* src, uint32_t width, uint32_t height,
                             int channels, float radius, float strength, float threshold);
    
    // Edge detection filters
    FilterResult edge_detect(const uint8_t* src, uint32_t width, uint32_t height,
                            int channels, float threshold);
    
    FilterResult sobel_x(const uint8_t* src, uint32_t width, uint32_t height, int channels);
    FilterResult sobel_y(const uint8_t* src, uint32_t width, uint32_t height, int channels);
    FilterResult laplacian(const uint8_t* src, uint32_t width, uint32_t height, int channels);
    
    // Artistic filters
    FilterResult emboss(const uint8_t* src, uint32_t width, uint32_t height,
                       int channels, float strength);
    
    FilterResult oil_painting(const uint8_t* src, uint32_t width, uint32_t height,
                             int channels, int radius, int intensity_levels);
    
    FilterResult kuwahara(const uint8_t* src, uint32_t width, uint32_t height,
                         int channels, int radius);
    
    // Noise reduction filters
    FilterResult noise_reduction(const uint8_t* src, uint32_t width, uint32_t height,
                                int channels, float strength);
    
    FilterResult bilateral_filter(const uint8_t* src, uint32_t width, uint32_t height,
                                 int channels, float spatial_sigma, float intensity_sigma);
    
    FilterResult median_filter(const uint8_t* src, uint32_t width, uint32_t height,
                              int channels, int radius);
    
    // Custom convolution
    FilterResult apply_convolution(const uint8_t* src, uint32_t width, uint32_t height,
                                  int channels, const ConvolutionKernel& kernel);
    
    // Separable convolution (more efficient for large kernels)
    FilterResult apply_separable_convolution(const uint8_t* src, uint32_t width, uint32_t height,
                                           int channels, const std::vector<float>& h_kernel,
                                           const std::vector<float>& v_kernel);
    
    // Pre-defined kernels
    static ConvolutionKernel create_gaussian_kernel(float sigma, int size = 0);
    static ConvolutionKernel create_box_kernel(int size);
    static ConvolutionKernel create_sharpen_kernel(float strength);
    static ConvolutionKernel create_edge_kernel();
    static ConvolutionKernel create_emboss_kernel();
    static ConvolutionKernel create_sobel_x_kernel();
    static ConvolutionKernel create_sobel_y_kernel();
    static ConvolutionKernel create_laplacian_kernel();
    
    // Performance settings
    void enable_simd(bool enable) { use_simd_ = enable; }
    bool is_simd_enabled() const { return use_simd_; }
    
    void enable_multithreading(bool enable) { use_multithreading_ = enable; }
    bool is_multithreading_enabled() const { return use_multithreading_; }
    
    // Statistics
    struct FilterStats {
        uint64_t total_filters_applied;
        uint64_t total_pixels_processed;
        double total_processing_time_ms;
        double average_megapixels_per_second;
        std::vector<std::pair<FilterType, uint64_t>> filter_usage_count;
    };
    
    FilterStats get_stats() const { return stats_; }
    void reset_stats() { stats_ = {}; }
    
private:
    bool use_simd_;
    bool use_multithreading_;
    FilterStats stats_;
    simd_utils::SIMDMemoryPool memory_pool_;
    
    // Helper functions
    void update_stats(FilterType type, size_t pixel_count, double time_ms);
    bool validate_inputs(const uint8_t* src, uint32_t width, uint32_t height, int channels);
    
    // SIMD-optimized implementations
    void simd_box_blur_horizontal(const uint8_t* src, uint8_t* dst, uint32_t width, 
                                 uint32_t height, int channels, int radius);
    void simd_box_blur_vertical(const uint8_t* src, uint8_t* dst, uint32_t width,
                               uint32_t height, int channels, int radius);
    
    void simd_gaussian_blur_horizontal(const uint8_t* src, uint8_t* dst, uint32_t width,
                                      uint32_t height, int channels, const std::vector<float>& kernel);
    void simd_gaussian_blur_vertical(const uint8_t* src, uint8_t* dst, uint32_t width,
                                    uint32_t height, int channels, const std::vector<float>& kernel);
    
    void simd_convolve_3x3(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                          int channels, const ConvolutionKernel& kernel);
    
    void simd_convolve_separable(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                                int channels, const std::vector<float>& h_kernel,
                                const std::vector<float>& v_kernel);
    
    // Specialized SIMD functions
    void simd_sobel_gradient(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                            int channels, bool x_direction);
    
    void simd_median_filter_3x3(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                                int channels);
    
    void simd_bilateral_filter_impl(const uint8_t* src, uint8_t* dst, uint32_t width, uint32_t height,
                                   int channels, float spatial_sigma, float intensity_sigma);
    
    // Utility functions
    std::vector<float> create_gaussian_1d_kernel(float sigma, int& size);
    float gaussian_weight(float distance, float sigma);
    float intensity_weight(float intensity_diff, float sigma);
    
    // Multi-threading support
    void process_rows_parallel(const std::function<void(int, int)>& row_processor, 
                              int total_rows, int num_threads = 0);
};

// Advanced filtering operations

// Anisotropic diffusion for edge-preserving smoothing
struct AnisotropicDiffusionParams {
    int iterations;
    float time_step;
    float conductance;
    bool use_exponential_conductance;
    
    AnisotropicDiffusionParams() : iterations(5), time_step(0.125f), 
                                  conductance(3.0f), use_exponential_conductance(true) {}
};

FilterResult anisotropic_diffusion(const uint8_t* src, uint32_t width, uint32_t height,
                                  int channels, const AnisotropicDiffusionParams& params);

// Non-local means denoising
struct NonLocalMeansParams {
    int search_window_size;
    int patch_size;
    float filtering_strength;
    float similarity_threshold;
    
    NonLocalMeansParams() : search_window_size(21), patch_size(7), 
                           filtering_strength(3.0f), similarity_threshold(0.02f) {}
};

FilterResult non_local_means_denoising(const uint8_t* src, uint32_t width, uint32_t height,
                                      int channels, const NonLocalMeansParams& params);

// Guided filter for edge-preserving smoothing
FilterResult guided_filter(const uint8_t* input, const uint8_t* guide, 
                          uint32_t width, uint32_t height, int channels,
                          int radius, float epsilon);

// Morphological operations
enum class MorphOp {
    ERODE,
    DILATE,
    OPEN,
    CLOSE,
    GRADIENT,
    TOPHAT,
    BLACKHAT
};

struct MorphElement {
    std::vector<bool> mask;
    int width;
    int height;
    int anchor_x;
    int anchor_y;
    
    MorphElement(int w, int h) : width(w), height(h), anchor_x(w/2), anchor_y(h/2) {
        mask.resize(w * h, true);
    }
    
    static MorphElement create_rect(int width, int height);
    static MorphElement create_ellipse(int width, int height);
    static MorphElement create_cross(int size);
};

FilterResult morphological_operation(const uint8_t* src, uint32_t width, uint32_t height,
                                   int channels, MorphOp operation, const MorphElement& element);

// Frequency domain filtering using FFT
class FrequencyDomainFilter {
public:
    FrequencyDomainFilter();
    ~FrequencyDomainFilter();
    
    // Low-pass filter (removes high frequencies)
    FilterResult low_pass_filter(const uint8_t* src, uint32_t width, uint32_t height,
                                int channels, float cutoff_frequency);
    
    // High-pass filter (removes low frequencies)
    FilterResult high_pass_filter(const uint8_t* src, uint32_t width, uint32_t height,
                                 int channels, float cutoff_frequency);
    
    // Band-pass filter
    FilterResult band_pass_filter(const uint8_t* src, uint32_t width, uint32_t height,
                                 int channels, float low_cutoff, float high_cutoff);
    
    // Notch filter (removes specific frequencies)
    FilterResult notch_filter(const uint8_t* src, uint32_t width, uint32_t height,
                             int channels, float center_freq, float bandwidth);
    
private:
    // FFT implementation (simplified - would use a proper FFT library in practice)
    void fft_2d(float* real, float* imag, int width, int height, bool inverse = false);
    void apply_frequency_mask(float* real, float* imag, int width, int height,
                             const std::function<float(float, float)>& mask_func);
};

// Texture analysis and synthesis
struct TextureFeatures {
    float energy;
    float contrast;
    float correlation;
    float homogeneity;
    float entropy;
    std::vector<float> glcm_features;  // Gray-Level Co-occurrence Matrix features
};

TextureFeatures analyze_texture(const uint8_t* src, uint32_t width, uint32_t height,
                               int channels, int patch_size = 16);

// Filter chain for applying multiple filters in sequence
class FilterChain {
public:
    FilterChain();
    
    // Add filter to chain
    void add_filter(FilterType type, const FilterParams& params);
    void add_custom_filter(const std::function<FilterResult(const uint8_t*, uint32_t, uint32_t, int)>& filter);
    
    // Apply entire chain
    FilterResult apply_chain(const uint8_t* src, uint32_t width, uint32_t height, int channels);
    
    // Chain management
    void clear() { filters_.clear(); }
    size_t size() const { return filters_.size(); }
    
private:
    struct FilterStep {
        FilterType type;
        FilterParams params;
        std::function<FilterResult(const uint8_t*, uint32_t, uint32_t, int)> custom_filter;
        bool is_custom;
    };
    
    std::vector<FilterStep> filters_;
    FilterProcessor processor_;
};

} // namespace filters