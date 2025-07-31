#pragma once

#include <cstdint>
#include <cstring>
#include <algorithm>

// WebAssembly SIMD support
#ifdef __wasm__
#include <wasm_simd128.h>
#define SIMD_SUPPORTED 1
#else
#define SIMD_SUPPORTED 0
// Fallback definitions for non-WASM builds
typedef struct {
    uint8_t bytes[16];
} v128_t;
#endif

namespace simd_utils {

/**
 * SIMD utilities for high-performance image processing
 *
 * This module provides WebAssembly SIMD-accelerated functions for common
 * image processing operations, with automatic fallback to scalar code
 * when SIMD is not available.
 */

// Constants
constexpr size_t SIMD_WIDTH = 16;  // 128-bit SIMD vectors
constexpr size_t SIMD_ALIGNMENT = 16;

// SIMD availability check
bool is_simd_supported();

// Memory alignment utilities
void* aligned_malloc(size_t size, size_t alignment = SIMD_ALIGNMENT);
void aligned_free(void* ptr);

// Check if pointer is properly aligned for SIMD
bool is_aligned(const void* ptr, size_t alignment = SIMD_ALIGNMENT);

// Align size to SIMD boundary
size_t align_size(size_t size, size_t alignment = SIMD_ALIGNMENT);

// SIMD vector operations

// Load/Store operations
#if SIMD_SUPPORTED
v128_t simd_load(const void* ptr);
v128_t simd_load_unaligned(const void* ptr);
void simd_store(void* ptr, v128_t vec);
void simd_store_unaligned(void* ptr, v128_t vec);

// Create vectors
v128_t simd_splat_u8(uint8_t value);
v128_t simd_splat_u16(uint16_t value);
v128_t simd_splat_u32(uint32_t value);
v128_t simd_splat_f32(float value);

// Arithmetic operations
v128_t simd_add_u8(v128_t a, v128_t b);
v128_t simd_add_u16(v128_t a, v128_t b);
v128_t simd_add_u32(v128_t a, v128_t b);
v128_t simd_add_f32(v128_t a, v128_t b);

v128_t simd_sub_u8(v128_t a, v128_t b);
v128_t simd_sub_u16(v128_t a, v128_t b);
v128_t simd_sub_u32(v128_t a, v128_t b);
v128_t simd_sub_f32(v128_t a, v128_t b);

v128_t simd_mul_u16(v128_t a, v128_t b);
v128_t simd_mul_u32(v128_t a, v128_t b);
v128_t simd_mul_f32(v128_t a, v128_t b);

// Saturated arithmetic (clamps to type bounds)
v128_t simd_adds_u8(v128_t a, v128_t b);  // Saturated add
v128_t simd_subs_u8(v128_t a, v128_t b);  // Saturated subtract

// Comparison operations
v128_t simd_eq_u8(v128_t a, v128_t b);
v128_t simd_gt_u8(v128_t a, v128_t b);
v128_t simd_lt_u8(v128_t a, v128_t b);

// Bitwise operations
v128_t simd_and(v128_t a, v128_t b);
v128_t simd_or(v128_t a, v128_t b);
v128_t simd_xor(v128_t a, v128_t b);
v128_t simd_not(v128_t a);

// Shift operations
v128_t simd_shl_u16(v128_t a, int shift);
v128_t simd_shr_u16(v128_t a, int shift);
v128_t simd_shl_u32(v128_t a, int shift);
v128_t simd_shr_u32(v128_t a, int shift);

// Min/Max operations
v128_t simd_min_u8(v128_t a, v128_t b);
v128_t simd_max_u8(v128_t a, v128_t b);
v128_t simd_min_f32(v128_t a, v128_t b);
v128_t simd_max_f32(v128_t a, v128_t b);

// Lane extraction and insertion
uint8_t simd_extract_u8(v128_t vec, int lane);
uint16_t simd_extract_u16(v128_t vec, int lane);
uint32_t simd_extract_u32(v128_t vec, int lane);
float simd_extract_f32(v128_t vec, int lane);

v128_t simd_replace_u8(v128_t vec, int lane, uint8_t value);
v128_t simd_replace_u16(v128_t vec, int lane, uint16_t value);
v128_t simd_replace_u32(v128_t vec, int lane, uint32_t value);
v128_t simd_replace_f32(v128_t vec, int lane, float value);

// Swizzle and shuffle operations
v128_t simd_swizzle(v128_t vec, v128_t indices);
v128_t simd_shuffle(v128_t a, v128_t b, int c0, int c1, int c2, int c3,
                   int c4, int c5, int c6, int c7, int c8, int c9,
                   int c10, int c11, int c12, int c13, int c14, int c15);

// Type conversion
v128_t simd_convert_u8_to_u16_low(v128_t vec);   // Convert low 8 u8s to u16s
v128_t simd_convert_u8_to_u16_high(v128_t vec);  // Convert high 8 u8s to u16s
v128_t simd_convert_u16_to_u8(v128_t low, v128_t high);  // Pack u16s to u8s with saturation

// Horizontal operations (reduce across lanes)
uint32_t simd_horizontal_add_u8(v128_t vec);
uint32_t simd_horizontal_add_u16(v128_t vec);
uint32_t simd_horizontal_add_u32(v128_t vec);
float simd_horizontal_add_f32(v128_t vec);

uint8_t simd_horizontal_min_u8(v128_t vec);
uint8_t simd_horizontal_max_u8(v128_t vec);

#endif // SIMD_SUPPORTED

// High-level image processing functions with SIMD acceleration

// Memory copy with SIMD optimization
void simd_memcpy(void* dest, const void* src, size_t size);

// Memory set with SIMD optimization
void simd_memset(void* dest, uint8_t value, size_t size);

// Pixel format conversion helpers
void simd_rgb_to_rgba(const uint8_t* rgb, uint8_t* rgba, size_t pixel_count, uint8_t alpha = 255);
void simd_rgba_to_rgb(const uint8_t* rgba, uint8_t* rgb, size_t pixel_count);
void simd_rgb_to_bgr(const uint8_t* rgb, uint8_t* bgr, size_t pixel_count);
void simd_rgba_to_bgra(const uint8_t* rgba, uint8_t* bgra, size_t pixel_count);

// Grayscale conversion with SIMD
void simd_rgb_to_grayscale(const uint8_t* rgb, uint8_t* gray, size_t pixel_count);
void simd_rgba_to_grayscale(const uint8_t* rgba, uint8_t* gray, size_t pixel_count);

// Color channel operations
void simd_extract_channel(const uint8_t* src, uint8_t* dest, size_t pixel_count,
                         int channel, int channels_per_pixel);
void simd_merge_channels(const uint8_t* r, const uint8_t* g, const uint8_t* b,
                        uint8_t* rgb, size_t pixel_count);
void simd_merge_channels_rgba(const uint8_t* r, const uint8_t* g, const uint8_t* b, const uint8_t* a,
                             uint8_t* rgba, size_t pixel_count);

// Arithmetic operations on pixel arrays
void simd_add_pixels(const uint8_t* src1, const uint8_t* src2, uint8_t* dest, size_t pixel_count);
void simd_sub_pixels(const uint8_t* src1, const uint8_t* src2, uint8_t* dest, size_t pixel_count);
void simd_mul_pixels(const uint8_t* src, uint8_t* dest, float multiplier, size_t pixel_count);
void simd_add_scalar(const uint8_t* src, uint8_t* dest, uint8_t value, size_t pixel_count);

// Blend operations
void simd_alpha_blend(const uint8_t* src, const uint8_t* dest, uint8_t* result,
                     size_t pixel_count, float alpha);
void simd_multiply_blend(const uint8_t* src1, const uint8_t* src2, uint8_t* dest, size_t pixel_count);
void simd_screen_blend(const uint8_t* src1, const uint8_t* src2, uint8_t* dest, size_t pixel_count);

// Statistical operations
struct PixelStats {
    uint32_t sum_r, sum_g, sum_b;
    uint32_t min_r, min_g, min_b;
    uint32_t max_r, max_g, max_b;
    uint32_t pixel_count;
};

PixelStats simd_calculate_stats(const uint8_t* pixels, size_t pixel_count, int channels);

// Histogram calculation
void simd_calculate_histogram(const uint8_t* pixels, size_t pixel_count, int channels,
                             uint32_t* hist_r, uint32_t* hist_g, uint32_t* hist_b,
                             uint32_t* hist_a = nullptr);

// Convolution helper (for filters)
void simd_convolve_3x3(const uint8_t* src, uint8_t* dest, int width, int height, int channels,
                      const float kernel[9], float bias = 0.0f, bool normalize = true);

// Box filter (separable)
void simd_box_filter_horizontal(const uint8_t* src, uint8_t* dest, int width, int height,
                               int channels, int radius);
void simd_box_filter_vertical(const uint8_t* src, uint8_t* dest, int width, int height,
                             int channels, int radius);

// Transpose operation (useful for separable filters)
void simd_transpose_u8(const uint8_t* src, uint8_t* dest, int width, int height, int channels);

// Utility functions

// Performance measurement
class SIMDTimer {
public:
    SIMDTimer();
    void start();
    void stop();
    double elapsed_ms() const;
    double megapixels_per_second(size_t pixel_count) const;

private:
    uint64_t start_time_;
    uint64_t end_time_;
};

// Memory pool for aligned allocations
class SIMDMemoryPool {
public:
    SIMDMemoryPool(size_t pool_size = 1024 * 1024);  // 1MB default
    ~SIMDMemoryPool();

    void* allocate(size_t size);
    void deallocate(void* ptr);
    void reset();

    size_t total_size() const { return pool_size_; }
    size_t used_size() const { return used_size_; }
    size_t available_size() const { return pool_size_ - used_size_; }

private:
    uint8_t* pool_;
    size_t pool_size_;
    size_t used_size_;
    struct Block {
        void* ptr;
        size_t size;
        bool free;
    };
    std::vector<Block> blocks_;
};

// Prefetch hints for better cache performance
void simd_prefetch(const void* ptr, size_t size = 64);

} // namespace simd_utils
