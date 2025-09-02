#include <stdint.h>
#include <string.h>  // Basic C library functions

extern "C" {

// Simple hash function implementation
uint32_t simple_hash(const char* str, size_t len) {
    uint32_t hash = 5381;
    for (size_t i = 0; i < len; i++) {
        hash = ((hash << 5) + hash) + str[i];
    }
    return hash;
}

// WIT interface implementation using basic C library
uint64_t exports_example_minimal_system_system_ops_get_timestamp() {
    // Return a simple counter since we don't have full time library
    static uint64_t counter = 0;
    return ++counter;
}

uint32_t exports_example_minimal_system_system_ops_compute_hash(const char* data, size_t data_len) {
    return simple_hash(data, data_len);  // Uses string.h functions
}

}