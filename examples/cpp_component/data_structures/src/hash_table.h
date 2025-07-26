#pragma once

#include "memory_pool.h"
#include <cstdint>
#include <string>
#include <vector>
#include <functional>
#include <optional>

namespace data_structures {

/**
 * High-performance hash table implementation with multiple hash algorithms
 * and collision resolution strategies, optimized for WebAssembly.
 */

// Hash algorithm types
enum class HashAlgorithm {
    FNV1A,
    MURMUR3,
    XXHASH,
    SIP_HASH,
    CITY_HASH
};

// Collision resolution strategies
enum class CollisionStrategy {
    CHAINING,
    LINEAR_PROBING,
    QUADRATIC_PROBING,
    DOUBLE_HASHING,
    ROBIN_HOOD
};

// Hash table configuration
struct HashTableConfig {
    size_t initial_capacity;
    float load_factor_threshold;
    float shrink_threshold;
    bool enable_resize;
    HashAlgorithm hash_algorithm;
    CollisionStrategy collision_strategy;
    bool enable_stats;
    
    HashTableConfig() 
        : initial_capacity(16), load_factor_threshold(0.75f), 
          shrink_threshold(0.25f), enable_resize(true),
          hash_algorithm(HashAlgorithm::FNV1A),
          collision_strategy(CollisionStrategy::CHAINING),
          enable_stats(true) {}
};

// Hash table statistics
struct HashTableStats {
    uint32_t size;
    uint32_t capacity;
    float load_factor;
    uint32_t collision_count;
    uint32_t resize_count;
    uint32_t memory_usage;
    uint32_t max_chain_length;
    float average_chain_length;
    uint64_t total_lookups;
    uint64_t successful_lookups;
    double average_lookup_time_ns;
};

// Key-value pair entry
template<typename K, typename V>
struct HashEntry {
    K key;
    V value;
    uint64_t hash;
    HashEntry* next;  // For chaining
    bool is_deleted;  // For tombstone marking
    
    HashEntry() : next(nullptr), is_deleted(false) {}
    HashEntry(const K& k, const V& v, uint64_t h) 
        : key(k), value(v), hash(h), next(nullptr), is_deleted(false) {}
};

// Hash function implementations
class HashFunctions {
public:
    // FNV-1a hash (fast, good distribution)
    static uint64_t fnv1a_hash(const void* data, size_t len);
    static uint64_t fnv1a_hash(const std::string& str);
    
    // MurmurHash3 (excellent distribution)
    static uint64_t murmur3_hash(const void* data, size_t len, uint32_t seed = 0);
    static uint64_t murmur3_hash(const std::string& str, uint32_t seed = 0);
    
    // xxHash (very fast)
    static uint64_t xxhash(const void* data, size_t len, uint64_t seed = 0);
    static uint64_t xxhash(const std::string& str, uint64_t seed = 0);
    
    // SipHash (cryptographically secure)
    static uint64_t sip_hash(const void* data, size_t len, const uint8_t key[16]);
    
    // CityHash (Google's fast hash)
    static uint64_t city_hash(const void* data, size_t len);
    static uint64_t city_hash(const std::string& str);
    
    // Generic hash dispatcher
    static uint64_t hash(const void* data, size_t len, HashAlgorithm algo, uint64_t seed = 0);
};

// Main hash table class
template<typename K, typename V>
class HashTable {
public:
    using KeyType = K;
    using ValueType = V;
    using EntryType = HashEntry<K, V>;
    
    explicit HashTable(const HashTableConfig& config = HashTableConfig(),
                      MemoryPool* pool = nullptr);
    ~HashTable();
    
    // Core operations
    bool put(const K& key, const V& value);
    std::optional<V> get(const K& key);
    bool remove(const K& key);
    bool contains(const K& key) const;
    void clear();
    
    // Bulk operations
    void put_batch(const std::vector<std::pair<K, V>>& pairs);
    std::vector<std::optional<V>> get_batch(const std::vector<K>& keys);
    size_t remove_batch(const std::vector<K>& keys);
    
    // Iteration support
    class Iterator {
    public:
        Iterator(EntryType** buckets, size_t capacity, size_t index);
        
        Iterator& operator++();
        bool operator!=(const Iterator& other) const;
        std::pair<const K&, V&> operator*();
        
    private:
        EntryType** buckets_;
        size_t capacity_;
        size_t bucket_index_;
        EntryType* current_entry_;
        
        void advance_to_next_valid();
    };
    
    Iterator begin();
    Iterator end();
    
    // Information and statistics
    size_t size() const { return size_; }
    size_t capacity() const { return capacity_; }
    bool empty() const { return size_ == 0; }
    float load_factor() const { return static_cast<float>(size_) / capacity_; }
    
    HashTableStats get_stats() const;
    void reset_stats();
    
    // Configuration
    void set_load_factor_threshold(float threshold);
    void set_hash_algorithm(HashAlgorithm algo);
    void enable_auto_resize(bool enable);
    
    // Memory management
    size_t memory_usage() const;
    void reserve(size_t new_capacity);
    void shrink_to_fit();
    
    // Debugging and validation
    bool validate() const;
    void dump_structure() const;
    std::vector<size_t> get_bucket_sizes() const;
    
private:
    HashTableConfig config_;
    MemoryPool* memory_pool_;
    bool owns_pool_;
    
    EntryType** buckets_;
    size_t capacity_;
    size_t size_;
    uint32_t collision_count_;
    uint32_t resize_count_;
    
    // Statistics
    mutable uint64_t total_lookups_;
    mutable uint64_t successful_lookups_;
    mutable uint64_t total_lookup_time_ns_;
    
    // Hash function state
    uint64_t hash_seed_;
    uint8_t sip_key_[16];
    
    // Internal methods
    uint64_t hash_key(const K& key) const;
    size_t get_bucket_index(uint64_t hash) const;
    size_t get_probe_sequence(uint64_t hash, size_t attempt) const;
    
    EntryType* find_entry(const K& key, uint64_t hash) const;
    EntryType* find_entry_for_insertion(const K& key, uint64_t hash);
    
    bool resize(size_t new_capacity);
    void rehash();
    
    // Collision resolution implementations
    bool put_chaining(const K& key, const V& value, uint64_t hash);
    bool put_open_addressing(const K& key, const V& value, uint64_t hash);
    bool put_robin_hood(const K& key, const V& value, uint64_t hash);
    
    std::optional<V> get_chaining(const K& key, uint64_t hash) const;
    std::optional<V> get_open_addressing(const K& key, uint64_t hash) const;
    
    bool remove_chaining(const K& key, uint64_t hash);
    bool remove_open_addressing(const K& key, uint64_t hash);
    
    // Memory management helpers
    EntryType* allocate_entry();
    void deallocate_entry(EntryType* entry);
    EntryType** allocate_buckets(size_t count);
    void deallocate_buckets(EntryType** buckets, size_t count);
    
    // Utility methods
    bool should_resize_up() const;
    bool should_resize_down() const;
    size_t calculate_optimal_capacity(size_t min_capacity) const;
    
    // Robin Hood hashing helpers
    struct RobinHoodEntry {
        EntryType* entry;
        size_t distance;
    };
    
    size_t get_distance(uint64_t hash, size_t actual_index) const;
    void swap_entries(size_t index1, size_t index2);
    
    // Statistics helpers
    void update_lookup_stats(bool successful, uint64_t time_ns) const;
    size_t calculate_max_chain_length() const;
    float calculate_average_chain_length() const;
};

// Specialized hash table for string keys
class StringHashTable : public HashTable<std::string, std::vector<uint8_t>> {
public:
    explicit StringHashTable(const HashTableConfig& config = HashTableConfig(),
                            MemoryPool* pool = nullptr);
    
    // String-specific optimizations
    bool put(const char* key, const uint8_t* data, size_t size);
    std::optional<std::vector<uint8_t>> get(const char* key);
    bool remove(const char* key);
    bool contains(const char* key) const;
    
    // Prefix operations
    std::vector<std::string> keys_with_prefix(const std::string& prefix) const;
    size_t remove_with_prefix(const std::string& prefix);
    
    // Pattern matching
    std::vector<std::string> keys_matching_pattern(const std::string& pattern) const;
    
private:
    // String-specific hash optimizations
    uint64_t hash_cstring(const char* str) const;
    bool strings_equal(const char* s1, const std::string& s2) const;
};

// Concurrent hash table (thread-safe)
template<typename K, typename V>
class ConcurrentHashTable {
public:
    explicit ConcurrentHashTable(size_t segment_count = 16,
                                const HashTableConfig& config = HashTableConfig(),
                                MemoryPool* pool = nullptr);
    ~ConcurrentHashTable();
    
    // Thread-safe operations
    bool put(const K& key, const V& value);
    std::optional<V> get(const K& key) const;
    bool remove(const K& key);
    bool contains(const K& key) const;
    void clear();
    
    // Bulk operations (locked per segment)
    void put_batch(const std::vector<std::pair<K, V>>& pairs);
    std::vector<std::optional<V>> get_batch(const std::vector<K>& keys) const;
    
    // Global operations (require global lock)
    size_t size() const;
    HashTableStats get_combined_stats() const;
    
private:
    struct Segment {
        HashTable<K, V> table;
        mutable std::mutex mutex;
        
        Segment(const HashTableConfig& config, MemoryPool* pool)
            : table(config, pool) {}
    };
    
    std::vector<std::unique_ptr<Segment>> segments_;
    size_t segment_count_;
    mutable std::mutex global_mutex_;
    
    size_t get_segment_index(const K& key) const;
    Segment& get_segment(const K& key);
    const Segment& get_segment(const K& key) const;
};

// Hash table factory for creating optimized instances
class HashTableFactory {
public:
    // Create hash table optimized for specific use cases
    template<typename K, typename V>
    static std::unique_ptr<HashTable<K, V>> create_for_cache(
        size_t expected_size, MemoryPool* pool = nullptr);
    
    template<typename K, typename V>
    static std::unique_ptr<HashTable<K, V>> create_for_database(
        size_t expected_size, MemoryPool* pool = nullptr);
    
    template<typename K, typename V>
    static std::unique_ptr<HashTable<K, V>> create_for_real_time(
        size_t expected_size, MemoryPool* pool = nullptr);
    
    // Create concurrent hash table
    template<typename K, typename V>
    static std::unique_ptr<ConcurrentHashTable<K, V>> create_concurrent(
        size_t expected_size, size_t thread_count = 0, MemoryPool* pool = nullptr);
    
private:
    static HashTableConfig get_cache_config();
    static HashTableConfig get_database_config();
    static HashTableConfig get_real_time_config();
};

} // namespace data_structures

// Include template implementations
#include "hash_table.tpp"