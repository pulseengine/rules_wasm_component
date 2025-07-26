#include "simd_utils.h"
#include <cstdlib>
#include <cmath>
#include <vector>
#include <chrono>
#include <algorithm>

namespace simd_utils {

// SIMD availability check
bool is_simd_supported() {
    return SIMD_SUPPORTED;
}

// Memory alignment utilities
void* aligned_malloc(size_t size, size_t alignment) {
    void* ptr;
#ifdef _WIN32
    ptr = _aligned_malloc(size, alignment);
#else
    if (posix_memalign(&ptr, alignment, size) != 0) {
        return nullptr;
    }
#endif
    return ptr;
}

void aligned_free(void* ptr) {
    if (!ptr) return;
#ifdef _WIN32
    _aligned_free(ptr);
#else
    free(ptr);
#endif
}

bool is_aligned(const void* ptr, size_t alignment) {
    return (reinterpret_cast<uintptr_t>(ptr) % alignment) == 0;
}

size_t align_size(size_t size, size_t alignment) {
    return ((size + alignment - 1) / alignment) * alignment;
}

#if SIMD_SUPPORTED

// Load/Store operations
v128_t simd_load(const void* ptr) {
    return wasm_v128_load(ptr);
}

v128_t simd_load_unaligned(const void* ptr) {
    return wasm_v128_load(ptr);  // WebAssembly handles unaligned loads
}

void simd_store(void* ptr, v128_t vec) {
    wasm_v128_store(ptr, vec);
}

void simd_store_unaligned(void* ptr, v128_t vec) {
    wasm_v128_store(ptr, vec);  // WebAssembly handles unaligned stores
}

// Create vectors
v128_t simd_splat_u8(uint8_t value) {
    return wasm_u8x16_splat(value);
}

v128_t simd_splat_u16(uint16_t value) {
    return wasm_u16x8_splat(value);
}

v128_t simd_splat_u32(uint32_t value) {
    return wasm_u32x4_splat(value);
}

v128_t simd_splat_f32(float value) {
    return wasm_f32x4_splat(value);
}

// Arithmetic operations
v128_t simd_add_u8(v128_t a, v128_t b) {
    return wasm_u8x16_add(a, b);
}

v128_t simd_add_u16(v128_t a, v128_t b) {
    return wasm_u16x8_add(a, b);
}

v128_t simd_add_u32(v128_t a, v128_t b) {
    return wasm_u32x4_add(a, b);
}

v128_t simd_add_f32(v128_t a, v128_t b) {
    return wasm_f32x4_add(a, b);
}

v128_t simd_sub_u8(v128_t a, v128_t b) {
    return wasm_u8x16_sub(a, b);
}

v128_t simd_sub_u16(v128_t a, v128_t b) {
    return wasm_u16x8_sub(a, b);
}

v128_t simd_sub_u32(v128_t a, v128_t b) {
    return wasm_u32x4_sub(a, b);
}

v128_t simd_sub_f32(v128_t a, v128_t b) {
    return wasm_f32x4_sub(a, b);
}

v128_t simd_mul_u16(v128_t a, v128_t b) {
    return wasm_u16x8_mul(a, b);
}

v128_t simd_mul_u32(v128_t a, v128_t b) {
    return wasm_u32x4_mul(a, b);
}

v128_t simd_mul_f32(v128_t a, v128_t b) {
    return wasm_f32x4_mul(a, b);
}

// Saturated arithmetic
v128_t simd_adds_u8(v128_t a, v128_t b) {
    return wasm_u8x16_add_sat(a, b);
}

v128_t simd_subs_u8(v128_t a, v128_t b) {
    return wasm_u8x16_sub_sat(a, b);
}

// Comparison operations
v128_t simd_eq_u8(v128_t a, v128_t b) {
    return wasm_u8x16_eq(a, b);
}

v128_t simd_gt_u8(v128_t a, v128_t b) {
    return wasm_u8x16_gt(a, b);
}

v128_t simd_lt_u8(v128_t a, v128_t b) {
    return wasm_u8x16_lt(a, b);
}

// Bitwise operations
v128_t simd_and(v128_t a, v128_t b) {
    return wasm_v128_and(a, b);
}

v128_t simd_or(v128_t a, v128_t b) {
    return wasm_v128_or(a, b);
}

v128_t simd_xor(v128_t a, v128_t b) {
    return wasm_v128_xor(a, b);
}

v128_t simd_not(v128_t a) {
    return wasm_v128_not(a);
}

// Shift operations
v128_t simd_shl_u16(v128_t a, int shift) {
    return wasm_u16x8_shl(a, shift);
}

v128_t simd_shr_u16(v128_t a, int shift) {
    return wasm_u16x8_shr(a, shift);
}

v128_t simd_shl_u32(v128_t a, int shift) {
    return wasm_u32x4_shl(a, shift);
}

v128_t simd_shr_u32(v128_t a, int shift) {
    return wasm_u32x4_shr(a, shift);
}

// Min/Max operations
v128_t simd_min_u8(v128_t a, v128_t b) {
    return wasm_u8x16_min(a, b);
}

v128_t simd_max_u8(v128_t a, v128_t b) {
    return wasm_u8x16_max(a, b);
}

v128_t simd_min_f32(v128_t a, v128_t b) {
    return wasm_f32x4_min(a, b);
}

v128_t simd_max_f32(v128_t a, v128_t b) {
    return wasm_f32x4_max(a, b);
}

// Lane extraction and insertion
uint8_t simd_extract_u8(v128_t vec, int lane) {
    return wasm_u8x16_extract_lane(vec, lane);
}

uint16_t simd_extract_u16(v128_t vec, int lane) {
    return wasm_u16x8_extract_lane(vec, lane);
}

uint32_t simd_extract_u32(v128_t vec, int lane) {
    return wasm_u32x4_extract_lane(vec, lane);
}

float simd_extract_f32(v128_t vec, int lane) {
    return wasm_f32x4_extract_lane(vec, lane);
}

v128_t simd_replace_u8(v128_t vec, int lane, uint8_t value) {
    return wasm_u8x16_replace_lane(vec, lane, value);
}

v128_t simd_replace_u16(v128_t vec, int lane, uint16_t value) {
    return wasm_u16x8_replace_lane(vec, lane, value);
}

v128_t simd_replace_u32(v128_t vec, int lane, uint32_t value) {
    return wasm_u32x4_replace_lane(vec, lane, value);
}

v128_t simd_replace_f32(v128_t vec, int lane, float value) {
    return wasm_f32x4_replace_lane(vec, lane, value);
}

// Swizzle and shuffle operations
v128_t simd_swizzle(v128_t vec, v128_t indices) {
    return wasm_i8x16_swizzle(vec, indices);
}

v128_t simd_shuffle(v128_t a, v128_t b, int c0, int c1, int c2, int c3,
                   int c4, int c5, int c6, int c7, int c8, int c9,
                   int c10, int c11, int c12, int c13, int c14, int c15) {
    return wasm_i8x16_shuffle(a, b, c0, c1, c2, c3, c4, c5, c6, c7,
                             c8, c9, c10, c11, c12, c13, c14, c15);
}

// Type conversion
v128_t simd_convert_u8_to_u16_low(v128_t vec) {
    return wasm_u16x8_extend_low_u8x16(vec);
}

v128_t simd_convert_u8_to_u16_high(v128_t vec) {
    return wasm_u16x8_extend_high_u8x16(vec);
}

v128_t simd_convert_u16_to_u8(v128_t low, v128_t high) {
    return wasm_u8x16_narrow_i16x8(low, high);
}

// Horizontal operations
uint32_t simd_horizontal_add_u8(v128_t vec) {
    uint32_t sum = 0;
    for (int i = 0; i < 16; i++) {
        sum += wasm_u8x16_extract_lane(vec, i);
    }
    return sum;
}

uint32_t simd_horizontal_add_u16(v128_t vec) {
    uint32_t sum = 0;
    for (int i = 0; i < 8; i++) {
        sum += wasm_u16x8_extract_lane(vec, i);
    }
    return sum;
}

uint32_t simd_horizontal_add_u32(v128_t vec) {
    uint32_t sum = 0;
    for (int i = 0; i < 4; i++) {
        sum += wasm_u32x4_extract_lane(vec, i);
    }
    return sum;
}

float simd_horizontal_add_f32(v128_t vec) {
    float sum = 0.0f;
    for (int i = 0; i < 4; i++) {
        sum += wasm_f32x4_extract_lane(vec, i);
    }
    return sum;
}

uint8_t simd_horizontal_min_u8(v128_t vec) {
    uint8_t min_val = 255;
    for (int i = 0; i < 16; i++) {
        min_val = std::min(min_val, wasm_u8x16_extract_lane(vec, i));
    }
    return min_val;
}

uint8_t simd_horizontal_max_u8(v128_t vec) {
    uint8_t max_val = 0;
    for (int i = 0; i < 16; i++) {
        max_val = std::max(max_val, wasm_u8x16_extract_lane(vec, i));
    }
    return max_val;
}

#endif // SIMD_SUPPORTED

// High-level image processing functions

void simd_memcpy(void* dest, const void* src, size_t size) {
#if SIMD_SUPPORTED
    const uint8_t* src_ptr = static_cast<const uint8_t*>(src);
    uint8_t* dest_ptr = static_cast<uint8_t*>(dest);
    
    // Process 16-byte chunks with SIMD
    size_t simd_chunks = size / 16;
    for (size_t i = 0; i < simd_chunks; i++) {
        v128_t chunk = simd_load_unaligned(src_ptr + i * 16);
        simd_store_unaligned(dest_ptr + i * 16, chunk);
    }
    
    // Handle remaining bytes
    size_t remaining = size - (simd_chunks * 16);
    if (remaining > 0) {
        std::memcpy(dest_ptr + simd_chunks * 16, src_ptr + simd_chunks * 16, remaining);
    }
#else
    std::memcpy(dest, src, size);
#endif
}

void simd_memset(void* dest, uint8_t value, size_t size) {
#if SIMD_SUPPORTED
    uint8_t* dest_ptr = static_cast<uint8_t*>(dest);
    v128_t value_vec = simd_splat_u8(value);
    
    // Process 16-byte chunks with SIMD
    size_t simd_chunks = size / 16;
    for (size_t i = 0; i < simd_chunks; i++) {
        simd_store_unaligned(dest_ptr + i * 16, value_vec);
    }
    
    // Handle remaining bytes
    size_t remaining = size - (simd_chunks * 16);
    if (remaining > 0) {
        std::memset(dest_ptr + simd_chunks * 16, value, remaining);
    }
#else
    std::memset(dest, value, size);
#endif
}

void simd_rgb_to_rgba(const uint8_t* rgb, uint8_t* rgba, size_t pixel_count, uint8_t alpha) {
#if SIMD_SUPPORTED
    v128_t alpha_vec = simd_splat_u8(alpha);
    
    for (size_t i = 0; i < pixel_count; i += 4) {  // Process 4 pixels at a time
        if (i + 4 <= pixel_count) {
            // Load 12 bytes (4 RGB pixels)
            v128_t rgb_data = simd_load_unaligned(rgb + i * 3);
            
            // Shuffle to create RGBA layout
            // This is a simplified version - actual implementation would need careful shuffling
            for (int j = 0; j < 4 && (i + j) < pixel_count; j++) {
                rgba[(i + j) * 4 + 0] = rgb[(i + j) * 3 + 0];  // R
                rgba[(i + j) * 4 + 1] = rgb[(i + j) * 3 + 1];  // G
                rgba[(i + j) * 4 + 2] = rgb[(i + j) * 3 + 2];  // B
                rgba[(i + j) * 4 + 3] = alpha;                  // A
            }
        } else {
            // Handle remaining pixels
            for (size_t j = i; j < pixel_count; j++) {
                rgba[j * 4 + 0] = rgb[j * 3 + 0];  // R
                rgba[j * 4 + 1] = rgb[j * 3 + 1];  // G
                rgba[j * 4 + 2] = rgb[j * 3 + 2];  // B
                rgba[j * 4 + 3] = alpha;           // A
            }
            break;
        }
    }
#else
    for (size_t i = 0; i < pixel_count; i++) {
        rgba[i * 4 + 0] = rgb[i * 3 + 0];  // R
        rgba[i * 4 + 1] = rgb[i * 3 + 1];  // G
        rgba[i * 4 + 2] = rgb[i * 3 + 2];  // B
        rgba[i * 4 + 3] = alpha;           // A
    }
#endif
}

void simd_rgb_to_grayscale(const uint8_t* rgb, uint8_t* gray, size_t pixel_count) {
#if SIMD_SUPPORTED
    // ITU-R BT.709 luma coefficients (scaled to avoid floating point)
    // Y = 0.2126*R + 0.7152*G + 0.0722*B
    // Using fixed point: Y = (54*R + 183*G + 19*B) >> 8
    v128_t coeff_r = simd_splat_u16(54);
    v128_t coeff_g = simd_splat_u16(183);
    v128_t coeff_b = simd_splat_u16(19);
    
    for (size_t i = 0; i < pixel_count; i += 16) {
        size_t remaining = std::min(size_t(16), pixel_count - i);
        
        if (remaining >= 5) {  // Need at least 5 pixels for SIMD efficiency
            // Load RGB data (this is simplified - real implementation needs careful loading)
            for (size_t j = 0; j < remaining && (i + j) < pixel_count; j++) {
                uint16_t r = rgb[(i + j) * 3 + 0];
                uint16_t g = rgb[(i + j) * 3 + 1];
                uint16_t b = rgb[(i + j) * 3 + 2];
                
                uint16_t luma = (54 * r + 183 * g + 19 * b) >> 8;
                gray[i + j] = static_cast<uint8_t>(std::min(luma, uint16_t(255)));
            }
        } else {
            // Handle remaining pixels with scalar code
            for (size_t j = i; j < pixel_count; j++) {
                uint16_t r = rgb[j * 3 + 0];
                uint16_t g = rgb[j * 3 + 1];
                uint16_t b = rgb[j * 3 + 2];
                
                gray[j] = static_cast<uint8_t>((54 * r + 183 * g + 19 * b) >> 8);
            }
            break;
        }
    }
#else
    for (size_t i = 0; i < pixel_count; i++) {
        uint16_t r = rgb[i * 3 + 0];
        uint16_t g = rgb[i * 3 + 1];
        uint16_t b = rgb[i * 3 + 2];
        
        gray[i] = static_cast<uint8_t>((54 * r + 183 * g + 19 * b) >> 8);
    }
#endif
}

void simd_add_pixels(const uint8_t* src1, const uint8_t* src2, uint8_t* dest, size_t pixel_count) {
#if SIMD_SUPPORTED
    size_t simd_count = pixel_count - (pixel_count % 16);
    
    // Process 16 pixels at a time with SIMD
    for (size_t i = 0; i < simd_count; i += 16) {
        v128_t a = simd_load_unaligned(src1 + i);
        v128_t b = simd_load_unaligned(src2 + i);
        v128_t result = simd_adds_u8(a, b);  // Saturated add
        simd_store_unaligned(dest + i, result);
    }
    
    // Handle remaining pixels
    for (size_t i = simd_count; i < pixel_count; i++) {
        uint16_t sum = static_cast<uint16_t>(src1[i]) + static_cast<uint16_t>(src2[i]);
        dest[i] = static_cast<uint8_t>(std::min(sum, uint16_t(255)));
    }
#else
    for (size_t i = 0; i < pixel_count; i++) {
        uint16_t sum = static_cast<uint16_t>(src1[i]) + static_cast<uint16_t>(src2[i]);
        dest[i] = static_cast<uint8_t>(std::min(sum, uint16_t(255)));
    }
#endif
}

PixelStats simd_calculate_stats(const uint8_t* pixels, size_t pixel_count, int channels) {
    PixelStats stats = {0};
    
    if (channels < 3) {
        return stats;  // Need at least RGB
    }
    
#if SIMD_SUPPORTED
    v128_t sum_r_vec = simd_splat_u32(0);
    v128_t sum_g_vec = simd_splat_u32(0);
    v128_t sum_b_vec = simd_splat_u32(0);
    v128_t min_r_vec = simd_splat_u8(255);
    v128_t min_g_vec = simd_splat_u8(255);
    v128_t min_b_vec = simd_splat_u8(255);
    v128_t max_r_vec = simd_splat_u8(0);
    v128_t max_g_vec = simd_splat_u8(0);
    v128_t max_b_vec = simd_splat_u8(0);
    
    // Process pixels in chunks
    for (size_t i = 0; i < pixel_count; i++) {
        uint8_t r = pixels[i * channels + 0];
        uint8_t g = pixels[i * channels + 1];
        uint8_t b = pixels[i * channels + 2];
        
        stats.sum_r += r;
        stats.sum_g += g;
        stats.sum_b += b;
        
        stats.min_r = std::min(stats.min_r, static_cast<uint32_t>(r));
        stats.min_g = std::min(stats.min_g, static_cast<uint32_t>(g));
        stats.min_b = std::min(stats.min_b, static_cast<uint32_t>(b));
        
        stats.max_r = std::max(stats.max_r, static_cast<uint32_t>(r));
        stats.max_g = std::max(stats.max_g, static_cast<uint32_t>(g));
        stats.max_b = std::max(stats.max_b, static_cast<uint32_t>(b));
    }
#else
    stats.min_r = stats.min_g = stats.min_b = 255;
    stats.max_r = stats.max_g = stats.max_b = 0;
    
    for (size_t i = 0; i < pixel_count; i++) {
        uint8_t r = pixels[i * channels + 0];
        uint8_t g = pixels[i * channels + 1];
        uint8_t b = pixels[i * channels + 2];
        
        stats.sum_r += r;
        stats.sum_g += g;
        stats.sum_b += b;
        
        stats.min_r = std::min(stats.min_r, static_cast<uint32_t>(r));
        stats.min_g = std::min(stats.min_g, static_cast<uint32_t>(g));
        stats.min_b = std::min(stats.min_b, static_cast<uint32_t>(b));
        
        stats.max_r = std::max(stats.max_r, static_cast<uint32_t>(r));
        stats.max_g = std::max(stats.max_g, static_cast<uint32_t>(g));
        stats.max_b = std::max(stats.max_b, static_cast<uint32_t>(b));
    }
#endif
    
    stats.pixel_count = static_cast<uint32_t>(pixel_count);
    return stats;
}

// Performance measurement
SIMDTimer::SIMDTimer() : start_time_(0), end_time_(0) {}

void SIMDTimer::start() {
    start_time_ = std::chrono::high_resolution_clock::now().time_since_epoch().count();
}

void SIMDTimer::stop() {
    end_time_ = std::chrono::high_resolution_clock::now().time_since_epoch().count();
}

double SIMDTimer::elapsed_ms() const {
    return (end_time_ - start_time_) / 1000000.0;  // Convert nanoseconds to milliseconds
}

double SIMDTimer::megapixels_per_second(size_t pixel_count) const {
    double elapsed_sec = elapsed_ms() / 1000.0;
    if (elapsed_sec <= 0.0) return 0.0;
    return (pixel_count / 1000000.0) / elapsed_sec;
}

// Memory pool implementation
SIMDMemoryPool::SIMDMemoryPool(size_t pool_size) 
    : pool_size_(align_size(pool_size)), used_size_(0) {
    pool_ = static_cast<uint8_t*>(aligned_malloc(pool_size_));
    if (pool_) {
        blocks_.reserve(64);  // Pre-allocate space for block tracking
    }
}

SIMDMemoryPool::~SIMDMemoryPool() {
    aligned_free(pool_);
}

void* SIMDMemoryPool::allocate(size_t size) {
    if (!pool_) return nullptr;
    
    size = align_size(size);
    
    if (used_size_ + size > pool_size_) {
        return nullptr;  // Not enough space
    }
    
    void* ptr = pool_ + used_size_;
    used_size_ += size;
    
    Block block = {ptr, size, false};
    blocks_.push_back(block);
    
    return ptr;
}

void SIMDMemoryPool::deallocate(void* ptr) {
    for (auto& block : blocks_) {
        if (block.ptr == ptr) {
            block.free = true;
            break;
        }
    }
}

void SIMDMemoryPool::reset() {
    used_size_ = 0;
    blocks_.clear();
}

void simd_prefetch(const void* ptr, size_t size) {
    // WebAssembly doesn't have explicit prefetch instructions,
    // but we can hint to the runtime by touching the memory
    (void)ptr;
    (void)size;
}

} // namespace simd_utils