#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include <map>
#include <memory>
#include <chrono>
#include <optional>

namespace data_structures {

// Simple implementations of core data structures for testing/example purposes

class SimpleHashTable {
private:
    std::unordered_map<std::string, std::vector<uint8_t>> data_;
    std::string name_;
    uint64_t created_time_;
    uint32_t collision_count_ = 0;
    uint32_t resize_count_ = 0;

public:
    explicit SimpleHashTable(const std::string& name);

    bool put(const std::string& key, const std::vector<uint8_t>& value);
    std::optional<std::vector<uint8_t>> get(const std::string& key);
    bool remove(const std::string& key);
    bool contains(const std::string& key);
    void clear();
    std::vector<std::string> keys();
    std::vector<std::vector<uint8_t>> values();
    uint32_t size() const;

    // Stats
    uint32_t capacity() const;
    float load_factor() const;
    uint32_t collision_count() const;
    uint32_t resize_count() const;
    uint32_t memory_usage() const;
};

class SimpleBTree {
private:
    std::map<std::string, std::vector<uint8_t>> data_; // Using std::map as simple ordered container
    std::string name_;
    uint64_t created_time_;

public:
    explicit SimpleBTree(const std::string& name);

    bool insert(const std::string& key, const std::vector<uint8_t>& value);
    std::optional<std::vector<uint8_t>> search(const std::string& key);
    bool remove(const std::string& key);
    std::vector<std::pair<std::string, std::vector<uint8_t>>> range_query(
        const std::string& start_key, const std::string& end_key);

    std::optional<std::string> min_key();
    std::optional<std::string> max_key();
    std::optional<std::string> predecessor(const std::string& key);
    std::optional<std::string> successor(const std::string& key);

    // Stats
    uint32_t height() const;
    uint32_t node_count() const;
    uint32_t key_count() const;
    uint32_t memory_usage() const;
};

struct SimpleEdge {
    uint64_t source;
    uint64_t target;
    double weight;
    std::vector<uint8_t> data;
};

class SimpleGraph {
private:
    std::unordered_map<uint64_t, std::vector<uint8_t>> nodes_;
    std::vector<SimpleEdge> edges_;
    std::string name_;
    bool directed_;
    uint64_t created_time_;

public:
    explicit SimpleGraph(const std::string& name, bool directed = true);

    bool add_node(uint64_t node_id, const std::vector<uint8_t>& data = {});
    bool remove_node(uint64_t node_id);
    bool add_edge(uint64_t source, uint64_t target, double weight = 1.0,
                  const std::vector<uint8_t>& data = {});
    bool remove_edge(uint64_t source, uint64_t target);

    bool has_node(uint64_t node_id);
    bool has_edge(uint64_t source, uint64_t target);
    std::vector<uint64_t> get_neighbors(uint64_t node_id);
    std::vector<SimpleEdge> get_edges(uint64_t node_id);

    // Simplified algorithms
    std::vector<uint64_t> dfs(uint64_t start);
    std::vector<uint64_t> bfs(uint64_t start);
    std::vector<uint64_t> shortest_path(uint64_t start, uint64_t end);

    // Stats
    uint32_t node_count() const;
    uint32_t edge_count() const;
    double density() const;
    uint32_t memory_usage() const;
};

// Global collection manager
class CollectionManager {
private:
    std::unordered_map<std::string, std::unique_ptr<SimpleHashTable>> hash_tables_;
    std::unordered_map<std::string, std::unique_ptr<SimpleBTree>> btrees_;
    std::unordered_map<std::string, std::unique_ptr<SimpleGraph>> graphs_;

    uint32_t memory_limit_ = 1024 * 1024 * 100; // 100MB default
    uint32_t total_allocated_ = 0;
    uint32_t total_freed_ = 0;
    uint32_t peak_usage_ = 0;
    uint32_t allocation_count_ = 0;

public:
    static CollectionManager& instance();

    // Hash table management
    bool create_hash_table(const std::string& name);
    SimpleHashTable* get_hash_table(const std::string& name);

    // B-tree management
    bool create_btree(const std::string& name);
    SimpleBTree* get_btree(const std::string& name);

    // Graph management
    bool create_graph(const std::string& name, bool directed = true);
    SimpleGraph* get_graph(const std::string& name);

    // Collection management
    bool collection_exists(const std::string& name);
    bool delete_collection(const std::string& name);
    std::vector<std::string> list_collections();

    // Memory management
    uint32_t get_memory_usage() const;
    uint32_t get_total_allocated() const;
    uint32_t get_total_freed() const;
    uint32_t get_peak_usage() const;
    uint32_t get_allocation_count() const;

    void update_memory_stats(uint32_t allocated);
    bool set_memory_limit(uint32_t limit_bytes);
    uint32_t garbage_collect(); // Returns bytes freed

    // Performance tracking
    void record_operation();
    double get_operations_per_second();

private:
    CollectionManager() = default;
    uint64_t operation_count_ = 0;
    std::chrono::steady_clock::time_point start_time_ = std::chrono::steady_clock::now();
};

// Serialization helpers
std::vector<uint8_t> serialize_to_json(const std::unordered_map<std::string, std::vector<uint8_t>>& data);
std::vector<uint8_t> serialize_to_binary(const std::unordered_map<std::string, std::vector<uint8_t>>& data);
bool deserialize_from_json(const std::vector<uint8_t>& data,
                          std::unordered_map<std::string, std::vector<uint8_t>>& output);
bool deserialize_from_binary(const std::vector<uint8_t>& data,
                           std::unordered_map<std::string, std::vector<uint8_t>>& output);

} // namespace data_structures
