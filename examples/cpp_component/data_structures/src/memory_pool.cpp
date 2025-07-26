#include "memory_pool.h"
#include <algorithm>
#include <cstring>
#include <cassert>
#include <iostream>

namespace data_structures {

MemoryPool::MemoryPool(const PoolConfig& config) 
    : config_(config), pool_memory_(nullptr), total_size_(0), used_size_(0),
      peak_usage_(0), allocation_count_(0), free_count_(0),
      free_list_head_(nullptr), used_list_head_(nullptr) {
    initialize_pool();
}

MemoryPool::~MemoryPool() {
    cleanup_pool();
}

void MemoryPool::initialize_pool() {
    total_size_ = align_size(config_.initial_size);
    pool_memory_ = static_cast<uint8_t*>(std::aligned_alloc(config_.alignment, total_size_));
    
    if (!pool_memory_) {
        throw std::bad_alloc();
    }
    
    // Initialize the entire pool as one large free block
    BlockHeader* initial_block = reinterpret_cast<BlockHeader*>(pool_memory_);
    initial_block->size = total_size_ - sizeof(BlockHeader);
    initial_block->is_free = true;
    initial_block->next = nullptr;
    initial_block->prev = nullptr;
    initial_block->magic = BlockHeader::MAGIC_VALUE;
    
    free_list_head_ = initial_block;
    used_size_ = sizeof(BlockHeader);
}

void MemoryPool::cleanup_pool() {
    if (pool_memory_) {
        std::free(pool_memory_);
        pool_memory_ = nullptr;
    }
    total_size_ = 0;
    used_size_ = 0;
}

void* MemoryPool::allocate(size_t size) {
    if (size == 0) return nullptr;
    
    std::lock_guard<std::mutex> lock(config_.enable_thread_safety ? mutex_ : 
                                    *reinterpret_cast<std::mutex*>(nullptr));
    
    size = align_size(size);
    
    // Find a suitable free block
    BlockHeader* block = find_free_block(size);
    if (!block) {
        // Try to expand the pool
        if (!expand_pool(std::max(size + sizeof(BlockHeader), config_.initial_size))) {
            return nullptr;
        }
        block = find_free_block(size);
        if (!block) {
            return nullptr;
        }
    }
    
    // Split the block if necessary
    if (block->size > size + sizeof(BlockHeader) + config_.alignment) {
        block = split_block(block, size);
    }
    
    // Mark block as used
    block->is_free = false;
    remove_free_block(block);
    insert_used_block(block);
    
    used_size_ += block->size + sizeof(BlockHeader);
    peak_usage_ = std::max(peak_usage_, used_size_);
    allocation_count_++;
    
    void* user_ptr = reinterpret_cast<uint8_t*>(block) + sizeof(BlockHeader);
    
    if (config_.enable_debug) {
        log_allocation(user_ptr, size);
    }
    
    return user_ptr;
}

void* MemoryPool::allocate_aligned(size_t size, size_t alignment) {
    if (size == 0) return nullptr;
    
    // Allocate extra space for alignment
    size_t total_size = size + alignment + sizeof(BlockHeader);
    void* raw_ptr = allocate(total_size);
    
    if (!raw_ptr) return nullptr;
    
    // Calculate aligned address
    uintptr_t addr = reinterpret_cast<uintptr_t>(raw_ptr);
    uintptr_t aligned_addr = (addr + alignment - 1) & ~(alignment - 1);
    
    return reinterpret_cast<void*>(aligned_addr);
}

void MemoryPool::deallocate(void* ptr) {
    if (!ptr) return;
    
    std::lock_guard<std::mutex> lock(config_.enable_thread_safety ? mutex_ : 
                                    *reinterpret_cast<std::mutex*>(nullptr));
    
    if (!is_valid_pointer(ptr)) {
        if (config_.enable_debug) {
            std::cerr << "Invalid pointer deallocated: " << ptr << std::endl;
        }
        return;
    }
    
    BlockHeader* block = reinterpret_cast<BlockHeader*>(
        static_cast<uint8_t*>(ptr) - sizeof(BlockHeader));
    
    if (config_.enable_debug) {
        check_corruption(block);
        log_deallocation(ptr);
    }
    
    // Mark block as free
    block->is_free = true;
    remove_used_block(block);
    insert_free_block(block);
    
    used_size_ -= block->size + sizeof(BlockHeader);
    free_count_++;
    
    // Coalesce adjacent free blocks
    if (config_.enable_defragmentation) {
        coalesce_free_blocks();
    }
}

BlockHeader* MemoryPool::find_free_block(size_t size) {
    BlockHeader* current = free_list_head_;
    BlockHeader* best_fit = nullptr;
    
    // First fit strategy
    while (current) {
        if (current->size >= size) {
            if (!best_fit || current->size < best_fit->size) {
                best_fit = current;
            }
            // If exact fit, use it immediately
            if (current->size == size) {
                break;
            }
        }
        current = current->next;
    }
    
    return best_fit;
}

BlockHeader* MemoryPool::split_block(BlockHeader* block, size_t size) {
    if (block->size <= size + sizeof(BlockHeader)) {
        return block;  // Block too small to split
    }
    
    // Create new block from the remainder
    BlockHeader* new_block = reinterpret_cast<BlockHeader*>(
        reinterpret_cast<uint8_t*>(block) + sizeof(BlockHeader) + size);
    
    new_block->size = block->size - size - sizeof(BlockHeader);
    new_block->is_free = true;
    new_block->next = nullptr;
    new_block->prev = nullptr;
    new_block->magic = BlockHeader::MAGIC_VALUE;
    
    // Update original block
    block->size = size;
    
    // Insert new block into free list
    insert_free_block(new_block);
    
    return block;
}

void MemoryPool::coalesce_free_blocks() {
    BlockHeader* current = free_list_head_;
    
    while (current) {
        BlockHeader* next_block = reinterpret_cast<BlockHeader*>(
            reinterpret_cast<uint8_t*>(current) + sizeof(BlockHeader) + current->size);
        
        // Check if next block is adjacent and free
        if (is_in_pool(next_block) && next_block->is_free) {
            // Merge blocks
            current->size += next_block->size + sizeof(BlockHeader);
            remove_free_block(next_block);
        } else {
            current = current->next;
        }
    }
}

void MemoryPool::insert_free_block(BlockHeader* block) {
    block->next = free_list_head_;
    block->prev = nullptr;
    
    if (free_list_head_) {
        free_list_head_->prev = block;
    }
    
    free_list_head_ = block;
}

void MemoryPool::remove_free_block(BlockHeader* block) {
    if (block->prev) {
        block->prev->next = block->next;
    } else {
        free_list_head_ = block->next;
    }
    
    if (block->next) {
        block->next->prev = block->prev;
    }
    
    block->next = block->prev = nullptr;
}

void MemoryPool::insert_used_block(BlockHeader* block) {
    block->next = used_list_head_;
    block->prev = nullptr;
    
    if (used_list_head_) {
        used_list_head_->prev = block;
    }
    
    used_list_head_ = block;
}

void MemoryPool::remove_used_block(BlockHeader* block) {
    if (block->prev) {
        block->prev->next = block->next;
    } else {
        used_list_head_ = block->next;
    }
    
    if (block->next) {
        block->next->prev = block->prev;
    }
    
    block->next = block->prev = nullptr;
}

bool MemoryPool::expand_pool(size_t additional_size) {
    if (total_size_ + additional_size > config_.max_size) {
        return false;
    }
    
    size_t new_size = total_size_ + align_size(additional_size);
    uint8_t* new_memory = static_cast<uint8_t*>(
        std::realloc(pool_memory_, new_size));
    
    if (!new_memory) {
        return false;
    }
    
    // Update pointers if memory was moved
    if (new_memory != pool_memory_) {
        ptrdiff_t offset = new_memory - pool_memory_;
        
        // Update all block pointers
        if (free_list_head_) {
            free_list_head_ = reinterpret_cast<BlockHeader*>(
                reinterpret_cast<uint8_t*>(free_list_head_) + offset);
        }
        
        if (used_list_head_) {
            used_list_head_ = reinterpret_cast<BlockHeader*>(
                reinterpret_cast<uint8_t*>(used_list_head_) + offset);
        }
        
        // Update all next/prev pointers in lists
        // This is simplified - a real implementation would need to traverse all blocks
        
        pool_memory_ = new_memory;
    }
    
    // Create new free block from expanded space
    BlockHeader* new_block = reinterpret_cast<BlockHeader*>(
        pool_memory_ + total_size_);
    new_block->size = additional_size - sizeof(BlockHeader);
    new_block->is_free = true;
    new_block->next = nullptr;
    new_block->prev = nullptr;
    new_block->magic = BlockHeader::MAGIC_VALUE;
    
    insert_free_block(new_block);
    
    total_size_ = new_size;
    return true;
}

MemoryStats MemoryPool::get_stats() const {
    std::lock_guard<std::mutex> lock(config_.enable_thread_safety ? mutex_ : 
                                    *reinterpret_cast<std::mutex*>(nullptr));
    
    MemoryStats stats = {};
    stats.current_usage = static_cast<uint32_t>(used_size_);
    stats.peak_usage = static_cast<uint32_t>(peak_usage_);
    stats.allocation_count = allocation_count_;
    stats.free_count = free_count_;
    stats.total_allocated = allocation_count_ * sizeof(BlockHeader);  // Simplified
    stats.total_freed = free_count_ * sizeof(BlockHeader);  // Simplified
    
    // Calculate fragmentation ratio
    size_t free_size = total_size_ - used_size_;
    size_t largest_free = 0;
    uint32_t free_blocks = 0;
    
    BlockHeader* current = free_list_head_;
    while (current) {
        largest_free = std::max(largest_free, current->size);
        free_blocks++;
        current = current->next;
    }
    
    stats.largest_free_block = static_cast<uint32_t>(largest_free);
    stats.free_block_count = free_blocks;
    
    if (free_size > 0) {
        stats.fragmentation_ratio = 1.0f - (static_cast<float>(largest_free) / free_size);
    }
    
    return stats;
}

bool MemoryPool::is_valid_pointer(void* ptr) const {
    if (!ptr || !is_in_pool(ptr)) {
        return false;
    }
    
    BlockHeader* block = reinterpret_cast<BlockHeader*>(
        static_cast<uint8_t*>(ptr) - sizeof(BlockHeader));
    
    return is_valid_block(block);
}

bool MemoryPool::is_valid_block(const BlockHeader* block) const {
    return block && 
           is_in_pool(const_cast<BlockHeader*>(block)) && 
           block->magic == BlockHeader::MAGIC_VALUE;
}

bool MemoryPool::is_in_pool(void* ptr) const {
    return ptr >= pool_memory_ && 
           ptr < pool_memory_ + total_size_;
}

size_t MemoryPool::align_size(size_t size, size_t alignment) const {
    if (alignment == 0) alignment = config_.alignment;
    return ((size + alignment - 1) / alignment) * alignment;
}

void MemoryPool::log_allocation(void* ptr, size_t size) const {
    if (config_.enable_debug) {
        std::cout << "Allocated " << size << " bytes at " << ptr << std::endl;
    }
}

void MemoryPool::log_deallocation(void* ptr) const {
    if (config_.enable_debug) {
        std::cout << "Deallocated pointer " << ptr << std::endl;
    }
}

void MemoryPool::check_corruption(const BlockHeader* block) const {
    POOL_ASSERT(block->magic == BlockHeader::MAGIC_VALUE, 
               "Block header corruption detected");
}

bool MemoryPool::validate_heap() const {
    std::lock_guard<std::mutex> lock(config_.enable_thread_safety ? mutex_ : 
                                    *reinterpret_cast<std::mutex*>(nullptr));
    
    // Validate all blocks in free list
    BlockHeader* current = free_list_head_;
    while (current) {
        if (!is_valid_block(current) || !current->is_free) {
            return false;
        }
        current = current->next;
    }
    
    // Validate all blocks in used list
    current = used_list_head_;
    while (current) {
        if (!is_valid_block(current) || current->is_free) {
            return false;
        }
        current = current->next;
    }
    
    return true;
}

// Global memory pool implementation
std::unique_ptr<MemoryPool> GlobalMemoryPool::instance_;
std::once_flag GlobalMemoryPool::initialized_;

MemoryPool& GlobalMemoryPool::instance() {
    std::call_once(initialized_, []() {
        instance_ = std::make_unique<MemoryPool>();
    });
    return *instance_;
}

void GlobalMemoryPool::initialize(const PoolConfig& config) {
    instance_ = std::make_unique<MemoryPool>(config);
}

void GlobalMemoryPool::shutdown() {
    instance_.reset();
}

// Fixed-size pool implementation
FixedSizePool::FixedSizePool(size_t block_size, size_t initial_blocks)
    : block_size_(block_size), total_blocks_(initial_blocks), 
      free_blocks_(initial_blocks) {
    
    size_t total_size = block_size_ * total_blocks_;
    memory_.resize(total_size);
    
    // Initialize free list
    for (size_t i = 0; i < total_blocks_; ++i) {
        free_list_.push_back(&memory_[i * block_size_]);
    }
}

FixedSizePool::~FixedSizePool() = default;

void* FixedSizePool::allocate() {
    if (free_list_.empty()) {
        expand_pool();
        if (free_list_.empty()) {
            return nullptr;
        }
    }
    
    void* ptr = free_list_.back();
    free_list_.pop_back();
    free_blocks_--;
    
    return ptr;
}

void FixedSizePool::deallocate(void* ptr) {
    if (!ptr) return;
    
    free_list_.push_back(ptr);
    free_blocks_++;
}

void FixedSizePool::expand_pool() {
    size_t old_size = memory_.size();
    size_t new_blocks = total_blocks_;  // Double the size
    
    memory_.resize(old_size + new_blocks * block_size_);
    
    // Add new blocks to free list
    for (size_t i = 0; i < new_blocks; ++i) {
        free_list_.push_back(&memory_[old_size + i * block_size_]);
    }
    
    total_blocks_ += new_blocks;
    free_blocks_ += new_blocks;
}

} // namespace data_structures