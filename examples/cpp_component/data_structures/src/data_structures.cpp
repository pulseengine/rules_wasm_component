#include "data_structures.h"
#include <map>
#include <cstring>
#include <cstdio>

// Include generated WIT binding header
#include "data_structures_world.h"

namespace data_structures {

// Global collection storage (simplified)
static std::map<std::string, std::unique_ptr<SimpleHashTable>> hash_tables;
static std::map<std::string, std::unique_ptr<SimpleBTree>> btrees;
static std::map<std::string, std::unique_ptr<SimpleGraph>> graphs;

// SimpleHashTable Implementation
SimpleHashTable::SimpleHashTable(const std::string& name) : name_(name) {}

bool SimpleHashTable::put(const std::string& key, const std::vector<uint8_t>& value) {
    data_[key] = value;
    return true;
}

std::optional<std::vector<uint8_t>> SimpleHashTable::get(const std::string& key) {
    auto it = data_.find(key);
    return it != data_.end() ? std::make_optional(it->second) : std::nullopt;
}

bool SimpleHashTable::remove(const std::string& key) {
    return data_.erase(key) > 0;
}

bool SimpleHashTable::contains(const std::string& key) {
    return data_.find(key) != data_.end();
}

void SimpleHashTable::clear() {
    data_.clear();
}

std::vector<std::string> SimpleHashTable::keys() {
    std::vector<std::string> result;
    for (const auto& pair : data_) {
        result.push_back(pair.first);
    }
    return result;
}

std::vector<std::vector<uint8_t>> SimpleHashTable::values() {
    std::vector<std::vector<uint8_t>> result;
    for (const auto& pair : data_) {
        result.push_back(pair.second);
    }
    return result;
}

uint32_t SimpleHashTable::size() const {
    return data_.size();
}

uint32_t SimpleHashTable::capacity() const {
    return data_.bucket_count();
}

float SimpleHashTable::load_factor() const {
    return data_.load_factor();
}

uint32_t SimpleHashTable::collision_count() const {
    return collision_count_;
}

uint32_t SimpleHashTable::resize_count() const {
    return resize_count_;
}

uint32_t SimpleHashTable::memory_usage() const {
    uint32_t usage = sizeof(*this);
    for (const auto& pair : data_) {
        usage += pair.first.size() + pair.second.size();
    }
    return usage;
}

// SimpleBTree Implementation
SimpleBTree::SimpleBTree(const std::string& name) : name_(name) {}
bool SimpleBTree::insert(const std::string& key, const std::vector<uint8_t>& value) { return true; }
std::optional<std::vector<uint8_t>> SimpleBTree::search(const std::string& key) { return std::nullopt; }
bool SimpleBTree::remove(const std::string& key) { return true; }
std::vector<std::pair<std::string, std::vector<uint8_t>>> SimpleBTree::range_query(const std::string& start_key, const std::string& end_key) { return {}; }
std::optional<std::string> SimpleBTree::min_key() { return std::nullopt; }
std::optional<std::string> SimpleBTree::max_key() { return std::nullopt; }
std::optional<std::string> SimpleBTree::predecessor(const std::string& key) { return std::nullopt; }
std::optional<std::string> SimpleBTree::successor(const std::string& key) { return std::nullopt; }
uint32_t SimpleBTree::height() const { return 1; }
uint32_t SimpleBTree::node_count() const { return data_.size(); }
uint32_t SimpleBTree::key_count() const { return data_.size(); }
uint32_t SimpleBTree::memory_usage() const { return 0; }

// SimpleGraph Implementation
SimpleGraph::SimpleGraph(const std::string& name, bool directed) : name_(name), directed_(directed) {}
bool SimpleGraph::add_node(uint64_t node_id, const std::vector<uint8_t>& data) { return true; }
bool SimpleGraph::remove_node(uint64_t node_id) { return true; }
bool SimpleGraph::add_edge(uint64_t source, uint64_t target, double weight, const std::vector<uint8_t>& data) { return true; }
bool SimpleGraph::remove_edge(uint64_t source, uint64_t target) { return true; }
bool SimpleGraph::has_node(uint64_t node_id) { return false; }
bool SimpleGraph::has_edge(uint64_t source, uint64_t target) { return false; }
std::vector<uint64_t> SimpleGraph::get_neighbors(uint64_t node_id) { return {}; }
std::vector<SimpleEdge> SimpleGraph::get_edges(uint64_t node_id) { return {}; }
std::vector<uint64_t> SimpleGraph::dfs(uint64_t start) { return {}; }
std::vector<uint64_t> SimpleGraph::bfs(uint64_t start) { return {}; }
std::vector<uint64_t> SimpleGraph::shortest_path(uint64_t start, uint64_t end) { return {}; }
uint32_t SimpleGraph::node_count() const { return nodes_.size(); }
uint32_t SimpleGraph::edge_count() const { return edges_.size(); }
double SimpleGraph::density() const { return 0.0; }
uint32_t SimpleGraph::memory_usage() const { return 0; }

CollectionManager& CollectionManager::instance() {
    static CollectionManager instance_;
    return instance_;
}

bool CollectionManager::create_hash_table(const std::string& name) {
    if (collection_exists(name)) return false;
    hash_tables_[name] = std::make_unique<SimpleHashTable>(name);
    return true;
}

SimpleHashTable* CollectionManager::get_hash_table(const std::string& name) {
    auto it = hash_tables_.find(name);
    return it != hash_tables_.end() ? it->second.get() : nullptr;
}

bool CollectionManager::create_btree(const std::string& name) {
    return true; // Stub
}

SimpleBTree* CollectionManager::get_btree(const std::string& name) {
    return nullptr; // Stub
}

bool CollectionManager::create_graph(const std::string& name, bool directed) {
    return true; // Stub
}

SimpleGraph* CollectionManager::get_graph(const std::string& name) {
    return nullptr; // Stub
}

bool CollectionManager::collection_exists(const std::string& name) {
    return hash_tables_.find(name) != hash_tables_.end();
}

bool CollectionManager::delete_collection(const std::string& name) {
    return hash_tables_.erase(name) > 0;
}

std::vector<std::string> CollectionManager::list_collections() {
    std::vector<std::string> collections;
    for (const auto& pair : hash_tables_) {
        collections.push_back(pair.first);
    }
    return collections;
}

uint32_t CollectionManager::get_memory_usage() const { return 0; }
uint32_t CollectionManager::get_total_allocated() const { return total_allocated_; }
uint32_t CollectionManager::get_total_freed() const { return total_freed_; }
uint32_t CollectionManager::get_peak_usage() const { return peak_usage_; }
uint32_t CollectionManager::get_allocation_count() const { return allocation_count_; }
void CollectionManager::update_memory_stats(uint32_t allocated) {}
bool CollectionManager::set_memory_limit(uint32_t limit_bytes) { return true; }
uint32_t CollectionManager::garbage_collect() { return 0; }
void CollectionManager::record_operation() {}
double CollectionManager::get_operations_per_second() { return 0.0; }

// Serialization helpers (stub)
std::vector<uint8_t> serialize_to_json(const std::unordered_map<std::string, std::vector<uint8_t>>& data) { return {}; }
std::vector<uint8_t> serialize_to_binary(const std::unordered_map<std::string, std::vector<uint8_t>>& data) { return {}; }
bool deserialize_from_json(const std::vector<uint8_t>& data, std::unordered_map<std::string, std::vector<uint8_t>>& output) { return false; }
bool deserialize_from_binary(const std::vector<uint8_t>& data, std::unordered_map<std::string, std::vector<uint8_t>>& output) { return false; }

} // namespace data_structures

//
// WIT Binding Implementations - Minimal working stubs
//

extern "C" {

// Helper functions
std::string wit_string_to_string(const data_structures_world_string_t* s) {
    return std::string(reinterpret_cast<const char*>(s->ptr), s->len);
}

void string_to_wit_string(data_structures_world_string_t* out, const std::string& s) {
    data_structures_world_string_dup(out, s.c_str());
}

// Hash Table Interface - Minimal working implementations
bool exports_example_data_structures_data_structures_create_hash_table(data_structures_world_string_t *name, exports_example_data_structures_data_structures_hash_table_config_t *config) {
    std::string table_name = wit_string_to_string(name);
    data_structures::hash_tables[table_name] = std::make_unique<data_structures::SimpleHashTable>(table_name);
    return true;
}

bool exports_example_data_structures_data_structures_hash_put(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_value_type_t *value) {
    std::string name = wit_string_to_string(table_name);
    std::string k = wit_string_to_string(key);
    std::vector<uint8_t> v(value->ptr, value->ptr + value->len);

    auto it = data_structures::hash_tables.find(name);
    if (it != data_structures::hash_tables.end()) {
        return it->second->put(k, v);
    }
    return false;
}

void exports_example_data_structures_data_structures_hash_get(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_hash_result_t *ret) {
    std::string name = wit_string_to_string(table_name);
    std::string k = wit_string_to_string(key);

    auto it = data_structures::hash_tables.find(name);
    if (it != data_structures::hash_tables.end()) {
        auto result = it->second->get(k);
        if (result) {
            ret->tag = EXPORTS_EXAMPLE_DATA_STRUCTURES_DATA_STRUCTURES_HASH_RESULT_SUCCESS;
            ret->val.success.len = result->size();
            ret->val.success.ptr = static_cast<uint8_t*>(malloc(result->size()));
            if (ret->val.success.ptr && !result->empty()) {
                memcpy(ret->val.success.ptr, result->data(), result->size());
            }
            return;
        }
    }

    ret->tag = EXPORTS_EXAMPLE_DATA_STRUCTURES_DATA_STRUCTURES_HASH_RESULT_NOT_FOUND;
}

bool exports_example_data_structures_data_structures_hash_remove(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_key_type_t *key) {
    return true; // Stub
}

bool exports_example_data_structures_data_structures_hash_contains(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_key_type_t *key) {
    return false; // Stub
}

bool exports_example_data_structures_data_structures_hash_clear(data_structures_world_string_t *table_name) {
    return true; // Stub
}

void exports_example_data_structures_data_structures_hash_keys(data_structures_world_string_t *table_name, data_structures_world_list_key_type_t *ret) {
    ret->ptr = nullptr;
    ret->len = 0;
}

void exports_example_data_structures_data_structures_hash_values(data_structures_world_string_t *table_name, data_structures_world_list_value_type_t *ret) {
    ret->ptr = nullptr;
    ret->len = 0;
}

uint32_t exports_example_data_structures_data_structures_hash_size(data_structures_world_string_t *table_name) {
    return 0; // Stub
}

bool exports_example_data_structures_data_structures_hash_stats(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_hash_table_stats_t *ret) {
    return false; // Stub
}

// All remaining functions as minimal stubs
bool exports_example_data_structures_data_structures_create_btree(data_structures_world_string_t *name, exports_example_data_structures_data_structures_btree_config_t *config) { return true; }
bool exports_example_data_structures_data_structures_btree_insert(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_value_type_t *value) { return true; }
void exports_example_data_structures_data_structures_btree_search(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_btree_result_t *ret) { ret->tag = EXPORTS_EXAMPLE_DATA_STRUCTURES_DATA_STRUCTURES_BTREE_RESULT_NOT_FOUND; }
bool exports_example_data_structures_data_structures_btree_delete(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *key) { return true; }
void exports_example_data_structures_data_structures_btree_range_query(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *start_key, exports_example_data_structures_data_structures_key_type_t *end_key, data_structures_world_list_tuple2_key_type_value_type_t *ret) { ret->ptr = nullptr; ret->len = 0; }
bool exports_example_data_structures_data_structures_btree_min_key(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *ret) { return false; }
bool exports_example_data_structures_data_structures_btree_max_key(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *ret) { return false; }
bool exports_example_data_structures_data_structures_btree_predecessor(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_key_type_t *ret) { return false; }
bool exports_example_data_structures_data_structures_btree_successor(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_key_type_t *ret) { return false; }
bool exports_example_data_structures_data_structures_get_btree_stats(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_btree_stats_t *ret) { return false; }
bool exports_example_data_structures_data_structures_create_graph(data_structures_world_string_t *name, exports_example_data_structures_data_structures_graph_config_t *config) { return true; }
bool exports_example_data_structures_data_structures_graph_add_node(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t node_id, exports_example_data_structures_data_structures_value_type_t *maybe_data) { return true; }
bool exports_example_data_structures_data_structures_graph_remove_node(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t node_id) { return true; }
bool exports_example_data_structures_data_structures_graph_add_edge(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_edge_t *edge) { return true; }
bool exports_example_data_structures_data_structures_graph_remove_edge(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t source_node, exports_example_data_structures_data_structures_node_id_t to) { return true; }
bool exports_example_data_structures_data_structures_graph_has_node(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t node_id) { return false; }
bool exports_example_data_structures_data_structures_graph_has_edge(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t source_node, exports_example_data_structures_data_structures_node_id_t to) { return false; }
void exports_example_data_structures_data_structures_graph_get_neighbors(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t node_id, data_structures_world_list_node_id_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_graph_get_edges(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t node_id, exports_example_data_structures_data_structures_list_edge_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_graph_shortest_path(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t start, exports_example_data_structures_data_structures_node_id_t end, exports_example_data_structures_data_structures_path_result_t *ret) { ret->exists = false; ret->distance = 0.0; ret->path.ptr = nullptr; ret->path.len = 0; ret->edge_count = 0; }
void exports_example_data_structures_data_structures_graph_dfs(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t start, data_structures_world_list_node_id_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_graph_bfs(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_node_id_t start, data_structures_world_list_node_id_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_graph_connected_components(data_structures_world_string_t *graph_name, data_structures_world_list_list_node_id_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_graph_minimum_spanning_tree(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_list_edge_t *ret) { ret->ptr = nullptr; ret->len = 0; }
bool exports_example_data_structures_data_structures_get_graph_stats(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_graph_stats_t *ret) { return false; }
void exports_example_data_structures_data_structures_serialize_hash_table(data_structures_world_string_t *table_name, exports_example_data_structures_data_structures_serialization_format_t format, exports_example_data_structures_data_structures_serialization_result_t *ret) { ret->success = false; ret->data.is_some = false; ret->size = 0; ret->compression_ratio = 0.0; ret->error.is_some = true; string_to_wit_string(&ret->error.val, "Not implemented"); }
bool exports_example_data_structures_data_structures_deserialize_hash_table(data_structures_world_string_t *name, data_structures_world_list_u8_t *data, exports_example_data_structures_data_structures_serialization_format_t format) { return false; }
void exports_example_data_structures_data_structures_serialize_btree(data_structures_world_string_t *tree_name, exports_example_data_structures_data_structures_serialization_format_t format, exports_example_data_structures_data_structures_serialization_result_t *ret) { ret->success = false; ret->data.is_some = false; ret->size = 0; ret->compression_ratio = 0.0; ret->error.is_some = true; string_to_wit_string(&ret->error.val, "Not implemented"); }
bool exports_example_data_structures_data_structures_deserialize_btree(data_structures_world_string_t *name, data_structures_world_list_u8_t *data, exports_example_data_structures_data_structures_serialization_format_t format) { return false; }
void exports_example_data_structures_data_structures_serialize_graph(data_structures_world_string_t *graph_name, exports_example_data_structures_data_structures_serialization_format_t format, exports_example_data_structures_data_structures_serialization_result_t *ret) { ret->success = false; ret->data.is_some = false; ret->size = 0; ret->compression_ratio = 0.0; ret->error.is_some = true; string_to_wit_string(&ret->error.val, "Not implemented"); }
bool exports_example_data_structures_data_structures_deserialize_graph(data_structures_world_string_t *name, data_structures_world_list_u8_t *data, exports_example_data_structures_data_structures_serialization_format_t format) { return false; }
void exports_example_data_structures_data_structures_get_memory_stats(exports_example_data_structures_data_structures_memory_stats_t *ret) { ret->total_allocated = 0; ret->total_freed = 0; ret->current_usage = 0; ret->peak_usage = 0; ret->allocation_count = 0; ret->fragmentation_ratio = 0.0; }
bool exports_example_data_structures_data_structures_defragment_memory(void) { return true; }
bool exports_example_data_structures_data_structures_set_memory_limit(uint32_t limit_bytes) { return true; }
uint32_t exports_example_data_structures_data_structures_garbage_collect(void) { return 0; }
void exports_example_data_structures_data_structures_list_collections(exports_example_data_structures_data_structures_list_collection_info_t *ret) { ret->ptr = nullptr; ret->len = 0; }
bool exports_example_data_structures_data_structures_collection_exists(data_structures_world_string_t *name) { return false; }
bool exports_example_data_structures_data_structures_delete_collection(data_structures_world_string_t *name) { return false; }
bool exports_example_data_structures_data_structures_rename_collection(data_structures_world_string_t *old_name, data_structures_world_string_t *new_name) { return false; }
bool exports_example_data_structures_data_structures_clone_collection(data_structures_world_string_t *source_name, data_structures_world_string_t *dest_name) { return false; }
void exports_example_data_structures_data_structures_execute_batch(exports_example_data_structures_data_structures_list_batch_operation_t *operations, exports_example_data_structures_data_structures_batch_result_t *ret) { ret->success = false; ret->results.ptr = nullptr; ret->results.len = 0; ret->error_count = 0; ret->processing_time_ms = 0; }
exports_example_data_structures_data_structures_transaction_id_t exports_example_data_structures_data_structures_begin_transaction(void) { return 1; }
bool exports_example_data_structures_data_structures_commit_transaction(exports_example_data_structures_data_structures_transaction_id_t tx_id) { return true; }
bool exports_example_data_structures_data_structures_rollback_transaction(exports_example_data_structures_data_structures_transaction_id_t tx_id) { return true; }
bool exports_example_data_structures_data_structures_transaction_put(exports_example_data_structures_data_structures_transaction_id_t tx_id, data_structures_world_string_t *collection, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_value_type_t *value) { return true; }
void exports_example_data_structures_data_structures_transaction_get(exports_example_data_structures_data_structures_transaction_id_t tx_id, data_structures_world_string_t *collection, exports_example_data_structures_data_structures_key_type_t *key, exports_example_data_structures_data_structures_hash_result_t *ret) { ret->tag = EXPORTS_EXAMPLE_DATA_STRUCTURES_DATA_STRUCTURES_HASH_RESULT_NOT_FOUND; }
bool exports_example_data_structures_data_structures_transaction_delete(exports_example_data_structures_data_structures_transaction_id_t tx_id, data_structures_world_string_t *collection, exports_example_data_structures_data_structures_key_type_t *key) { return true; }
void exports_example_data_structures_data_structures_execute_query(data_structures_world_string_t *collection, data_structures_world_string_t *query, exports_example_data_structures_data_structures_query_result_t *ret) { ret->success = false; ret->rows.ptr = nullptr; ret->rows.len = 0; ret->row_count = 0; ret->execution_time_ms = 0; ret->error.is_some = true; string_to_wit_string(&ret->error.val, "Not implemented"); }
bool exports_example_data_structures_data_structures_create_index(data_structures_world_string_t *collection, data_structures_world_string_t *field_name, data_structures_world_string_t *index_type) { return false; }
bool exports_example_data_structures_data_structures_drop_index(data_structures_world_string_t *collection, data_structures_world_string_t *field_name) { return false; }
void exports_example_data_structures_data_structures_list_indexes(data_structures_world_string_t *collection, data_structures_world_list_string_t *ret) { ret->ptr = nullptr; ret->len = 0; }
void exports_example_data_structures_data_structures_get_performance_metrics(data_structures_world_string_t *collection, exports_example_data_structures_data_structures_performance_metrics_t *ret) { ret->operations_per_second = 0.0; ret->average_latency_ms = 0.0; ret->memory_efficiency = 0.0; ret->cache_hit_ratio = 0.0; ret->error_rate = 0.0; }
bool exports_example_data_structures_data_structures_reset_performance_metrics(data_structures_world_string_t *collection) { return true; }
void exports_example_data_structures_data_structures_get_system_config(exports_example_data_structures_data_structures_system_config_t *ret) { ret->memory_limit = 1024 * 1024 * 100; ret->cache_size = 1024 * 1024 * 10; ret->max_collections = 1000; ret->enable_compression = false; ret->enable_encryption = false; string_to_wit_string(&ret->log_level, "info"); }
bool exports_example_data_structures_data_structures_update_system_config(exports_example_data_structures_data_structures_system_config_t *config) { return true; }
bool exports_example_data_structures_data_structures_health_check(void) { return true; }
bool exports_example_data_structures_data_structures_validate_collection(data_structures_world_string_t *name) { return true; }
bool exports_example_data_structures_data_structures_repair_collection(data_structures_world_string_t *name) { return true; }
void exports_example_data_structures_data_structures_export_diagnostics(data_structures_world_list_u8_t *ret) { std::string diag = "System healthy"; ret->len = diag.size(); ret->ptr = static_cast<uint8_t*>(malloc(diag.size())); if (ret->ptr) memcpy(ret->ptr, diag.data(), diag.size()); }

} // extern "C"

// Simple test main function
int main() {
    // Test basic functionality
    data_structures_world_string_t table_name;
    data_structures_world_string_dup(&table_name, "test_table");

    exports_example_data_structures_data_structures_hash_table_config_t config = {
        .initial_capacity = 16,
        .load_factor = 0.75f,
        .enable_resize = true
    };
    data_structures_world_string_dup(&config.hash_algorithm, "fnv");

    // Create hash table
    bool created = exports_example_data_structures_data_structures_create_hash_table(&table_name, &config);

    if (created) {
        // Test put operation
        data_structures_world_string_t key;
        data_structures_world_string_dup(&key, "test_key");

        exports_example_data_structures_data_structures_value_type_t value;
        std::string test_value = "Hello, World!";
        value.len = test_value.size();
        value.ptr = reinterpret_cast<uint8_t*>(const_cast<char*>(test_value.data()));

        bool put_result = exports_example_data_structures_data_structures_hash_put(&table_name, &key, &value);

        if (put_result) {
            // Test get operation
            exports_example_data_structures_data_structures_hash_result_t get_result;
            exports_example_data_structures_data_structures_hash_get(&table_name, &key, &get_result);

            if (get_result.tag == EXPORTS_EXAMPLE_DATA_STRUCTURES_DATA_STRUCTURES_HASH_RESULT_SUCCESS) {
                printf("Success! Retrieved value of length: %zu\n", get_result.val.success.len);
                return 0; // Success
            } else {
                printf("Failed to get value\n");
                return 1;
            }
        } else {
            printf("Failed to put value\n");
            return 1;
        }
    } else {
        printf("Failed to create hash table\n");
        return 1;
    }
}
