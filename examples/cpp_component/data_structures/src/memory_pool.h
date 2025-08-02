#pragma once

#include <cstdint>
#include <cstddef>
#include <memory>
#include <vector>
#include <mutex>

namespace data_structures {

/**
 * High-performance memory pool for WebAssembly components
 *
 * Provides efficient memory allocation with minimal fragmentation,
 * designed specifically for data structure implementations in WASM.
 */

// Memory block header for tracking allocations
struct BlockHeader {
    size_t size;
    bool is_free;
    BlockHeader* next;
    BlockHeader* prev;
    uint32_t magic;  // For corruption detection

    static constexpr uint32_t MAGIC_VALUE = 0xDEADBEEF;
};

// Memory pool statistics
struct MemoryStats {
    uint32_t total_allocated;
    uint32_t total_freed;
    uint32_t current_usage;
    uint32_t peak_usage;
    uint32_t allocation_count;
    uint32_t free_count;
    float fragmentation_ratio;
    uint32_t largest_free_block;
    uint32_t free_block_count;
};

// Memory pool configuration
struct PoolConfig {
    size_t initial_size;
    size_t max_size;
    size_t alignment;
    bool enable_debug;
    bool enable_thread_safety;
    bool enable_defragmentation;
    float growth_factor;

    PoolConfig() : initial_size(1024 * 1024),     // 1MB
                   max_size(16 * 1024 * 1024),    // 16MB
                   alignment(8),
                   enable_debug(false),
                   enable_thread_safety(false),
                   enable_defragmentation(true),
                   growth_factor(2.0f) {}
};

class MemoryPool {
public:
    explicit MemoryPool(const PoolConfig& config = PoolConfig());
    ~MemoryPool();

    // Disable copy/move to prevent issues with raw pointers
    MemoryPool(const MemoryPool&) = delete;
    MemoryPool& operator=(const MemoryPool&) = delete;
    MemoryPool(MemoryPool&&) = delete;
    MemoryPool& operator=(MemoryPool&&) = delete;

    // Core allocation functions
    void* allocate(size_t size);
    void* allocate_aligned(size_t size, size_t alignment);
    void* reallocate(void* ptr, size_t new_size);
    void deallocate(void* ptr);

    // Bulk operations
    std::vector<void*> allocate_bulk(const std::vector<size_t>& sizes);
    void deallocate_bulk(const std::vector<void*>& ptrs);

    // Memory management
    bool defragment();
    void garbage_collect();
    bool expand_pool(size_t additional_size);
    void reset();

    // Information and statistics
    MemoryStats get_stats() const;
    size_t get_total_size() const { return total_size_; }
    size_t get_used_size() const { return used_size_; }
    size_t get_free_size() const { return total_size_ - used_size_; }
    bool is_valid_pointer(void* ptr) const;
    size_t get_allocation_size(void* ptr) const;

    // Configuration
    void set_debug_enabled(bool enabled) { config_.enable_debug = enabled; }
    bool is_debug_enabled() const { return config_.enable_debug; }

    // Validation and debugging
    bool validate_heap() const;
    void dump_heap(bool detailed = false) const;
    std::vector<void*> find_leaks() const;

    // Thread safety
    void enable_thread_safety(bool enable);
    bool is_thread_safe() const { return config_.enable_thread_safety; }

private:
    PoolConfig config_;
    uint8_t* pool_memory_;
    size_t total_size_;
    size_t used_size_;
    size_t peak_usage_;
    uint32_t allocation_count_;
    uint32_t free_count_;

    BlockHeader* free_list_head_;
    BlockHeader* used_list_head_;

    mutable std::mutex mutex_;

    // Internal helper functions
    void initialize_pool();
    void cleanup_pool();
    BlockHeader* find_free_block(size_t size);
    BlockHeader* split_block(BlockHeader* block, size_t size);
    void coalesce_free_blocks();
    void insert_free_block(BlockHeader* block);
    void remove_free_block(BlockHeader* block);
    void insert_used_block(BlockHeader* block);
    void remove_used_block(BlockHeader* block);

    // Alignment helpers
    size_t align_size(size_t size, size_t alignment = 0) const;
    bool is_aligned(void* ptr, size_t alignment) const;

    // Validation helpers
    bool is_valid_block(const BlockHeader* block) const;
    bool is_in_pool(void* ptr) const;

    // Debug helpers
    void log_allocation(void* ptr, size_t size) const;
    void log_deallocation(void* ptr) const;
    void check_corruption(const BlockHeader* block) const;
};

// Template allocator for STL containers
template<typename T>
class PoolAllocator {
public:
    using value_type = T;
    using pointer = T*;
    using const_pointer = const T*;
    using reference = T&;
    using const_reference = const T&;
    using size_type = size_t;
    using difference_type = ptrdiff_t;

    template<typename U>
    struct rebind {
        using other = PoolAllocator<U>;
    };

    explicit PoolAllocator(MemoryPool* pool) : pool_(pool) {}

    template<typename U>
    PoolAllocator(const PoolAllocator<U>& other) : pool_(other.pool_) {}

    pointer allocate(size_type n) {
        return static_cast<pointer>(pool_->allocate(n * sizeof(T)));
    }

    void deallocate(pointer p, size_type) {
        pool_->deallocate(p);
    }

    template<typename U>
    bool operator==(const PoolAllocator<U>& other) const {
        return pool_ == other.pool_;
    }

    template<typename U>
    bool operator!=(const PoolAllocator<U>& other) const {
        return !(*this == other);
    }

    MemoryPool* pool_;
};

// Specialized memory pools for different use cases

// Fixed-size block allocator for frequent allocations of same size
class FixedSizePool {
public:
    FixedSizePool(size_t block_size, size_t initial_blocks = 64);
    ~FixedSizePool();

    void* allocate();
    void deallocate(void* ptr);

    size_t get_block_size() const { return block_size_; }
    size_t get_total_blocks() const { return total_blocks_; }
    size_t get_free_blocks() const { return free_blocks_; }

private:
    size_t block_size_;
    size_t total_blocks_;
    size_t free_blocks_;
    std::vector<uint8_t> memory_;
    std::vector<void*> free_list_;

    void expand_pool();
};

// Stack allocator for temporary allocations
class StackAllocator {
public:
    explicit StackAllocator(size_t size);
    ~StackAllocator();

    void* allocate(size_t size);
    void reset();

    size_t get_used_size() const { return offset_; }
    size_t get_total_size() const { return size_; }

private:
    uint8_t* memory_;
    size_t size_;
    size_t offset_;
};

// Ring buffer allocator for streaming data
class RingBufferAllocator {
public:
    explicit RingBufferAllocator(size_t size);
    ~RingBufferAllocator();

    void* allocate(size_t size);
    bool can_allocate(size_t size) const;

    size_t get_used_size() const;
    size_t get_free_size() const;

private:
    uint8_t* memory_;
    size_t size_;
    size_t head_;
    size_t tail_;
    bool full_;
};

// Global memory pool instance
class GlobalMemoryPool {
public:
    static MemoryPool& instance();
    static void initialize(const PoolConfig& config = PoolConfig());
    static void shutdown();

private:
    static std::unique_ptr<MemoryPool> instance_;
    static std::once_flag initialized_;
};

// RAII memory manager for automatic cleanup
template<typename T>
class PoolPtr {
public:
    explicit PoolPtr(MemoryPool* pool = nullptr) : pool_(pool), ptr_(nullptr) {}

    explicit PoolPtr(T* ptr, MemoryPool* pool) : pool_(pool), ptr_(ptr) {}

    ~PoolPtr() {
        reset();
    }

    // Move semantics
    PoolPtr(PoolPtr&& other) noexcept : pool_(other.pool_), ptr_(other.ptr_) {
        other.ptr_ = nullptr;
        other.pool_ = nullptr;
    }

    PoolPtr& operator=(PoolPtr&& other) noexcept {
        if (this != &other) {
            reset();
            pool_ = other.pool_;
            ptr_ = other.ptr_;
            other.ptr_ = nullptr;
            other.pool_ = nullptr;
        }
        return *this;
    }

    // Disable copy
    PoolPtr(const PoolPtr&) = delete;
    PoolPtr& operator=(const PoolPtr&) = delete;

    T* get() const { return ptr_; }
    T* operator->() const { return ptr_; }
    T& operator*() const { return *ptr_; }

    explicit operator bool() const { return ptr_ != nullptr; }

    T* release() {
        T* tmp = ptr_;
        ptr_ = nullptr;
        return tmp;
    }

    void reset(T* ptr = nullptr) {
        if (ptr_ && pool_) {
            pool_->deallocate(ptr_);
        }
        ptr_ = ptr;
    }

    static PoolPtr make(MemoryPool* pool, size_t count = 1) {
        T* ptr = static_cast<T*>(pool->allocate(sizeof(T) * count));
        return PoolPtr(ptr, pool);
    }

private:
    MemoryPool* pool_;
    T* ptr_;
};

// Utility functions
template<typename T, typename... Args>
PoolPtr<T> make_pool_unique(MemoryPool* pool, Args&&... args) {
    auto ptr = PoolPtr<T>::make(pool);
    if (ptr) {
        new (ptr.get()) T(std::forward<Args>(args)...);
    }
    return ptr;
}

// Memory debugging utilities
#ifdef DEBUG
#define POOL_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            fprintf(stderr, "Pool assertion failed: %s at %s:%d\n", \
                    message, __FILE__, __LINE__); \
            abort(); \
        } \
    } while(0)
#else
#define POOL_ASSERT(condition, message) do { } while(0)
#endif

} // namespace data_structures
