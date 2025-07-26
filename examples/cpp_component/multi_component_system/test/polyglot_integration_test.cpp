#include <gtest/gtest.h>
#include "../components/message_bus.h"
#include "../components/metrics_collector.h"
#include "../../http_service/src/http_utils.h"
#include <chrono>
#include <thread>
#include <vector>
#include <string>
#include <memory>

using namespace multi_component_system;

/**
 * Polyglot Integration Tests
 * 
 * Tests the integration between C++, Rust, and Go components in the
 * multi-component system, verifying cross-language communication,
 * performance characteristics, and system reliability.
 */

class PolyglotIntegrationTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Initialize message bus for cross-component communication
        MessageBusConfig config;
        config.max_queue_size = 10000;
        config.enable_compression = true;
        config.enable_encryption = false; // Disabled for testing
        config.heartbeat_interval_seconds = 5;
        
        message_bus_ = std::make_unique<MessageBus>(config);
        ASSERT_TRUE(message_bus_->start());
        
        // Initialize metrics collector
        metrics_collector_ = std::make_unique<MetricsCollector>();
        
        // Wait for services to be ready
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    void TearDown() override {
        if (message_bus_) {
            message_bus_->stop();
        }
    }

    // Helper method to simulate component startup
    void StartComponent(const std::string& component_id, const std::string& language) {
        ServiceInfo service;
        service.service_id = component_id;
        service.service_name = component_id;
        service.version = "1.0.0";
        service.endpoint = "/" + component_id;
        service.capabilities = {language + "_component", "multi_language_system"};
        service.metadata["language"] = language;
        service.metadata["test_mode"] = "true";
        
        ASSERT_TRUE(message_bus_->register_service(service));
    }

    // Helper method to send cross-language requests
    bool SendCrossLanguageRequest(const std::string& from_component, 
                                 const std::string& to_component,
                                 const std::string& payload,
                                 std::chrono::milliseconds timeout = std::chrono::milliseconds(5000)) {
        bool response_received = false;
        
        ResponseHandler handler = [&response_received](const Message& response, bool success) {
            response_received = success;
        };
        
        std::vector<uint8_t> data(payload.begin(), payload.end());
        bool sent = message_bus_->send_request(to_component, data, handler, 
                                              timeout.count() / 1000);
        
        if (!sent) return false;
        
        // Wait for response
        auto start = std::chrono::steady_clock::now();
        while (!response_received && 
               std::chrono::steady_clock::now() - start < timeout) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        
        return response_received;
    }

private:
    std::unique_ptr<MessageBus> message_bus_;
    std::unique_ptr<MetricsCollector> metrics_collector_;
};

// Test 1: C++ to Rust Communication
TEST_F(PolyglotIntegrationTest, CppToRustCommunication) {
    // Start C++ auth service and Rust user service
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    
    // Test authentication request from C++ to validation in Rust user service
    std::string auth_request = R"({
        "username": "test_user",
        "password": "test_password",
        "action": "validate_user"
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("auth-service-cpp", "user-service-rust", auth_request));
}

// Test 2: Rust to Go Communication  
TEST_F(PolyglotIntegrationTest, RustToGoCommunication) {
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Test user activity event from Rust to Go analytics
    std::string user_event = R"({
        "event_type": "user_login",
        "user_id": "user123",
        "timestamp": 1640995200,
        "properties": {
            "login_method": "oauth",
            "device_type": "desktop"
        }
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("user-service-rust", "analytics-service-go", user_event));
}

// Test 3: Go to C++ Communication
TEST_F(PolyglotIntegrationTest, GoToCppCommunication) {
    StartComponent("analytics-service-go", "go");
    StartComponent("api-gateway-cpp", "cpp");
    
    // Test analytics results from Go to C++ API gateway
    std::string analytics_data = R"({
        "metric_type": "user_engagement",
        "value": 85.5,
        "time_window": "1h",
        "dimensions": {
            "country": "US",
            "device": "mobile"
        }
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("analytics-service-go", "api-gateway-cpp", analytics_data));
}

// Test 4: Three-Way Communication (C++ -> Rust -> Go)
TEST_F(PolyglotIntegrationTest, ThreeWayCommunication) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Simulate complex workflow across all three languages
    
    // Step 1: C++ auth service authenticates user
    std::string auth_request = R"({
        "username": "integration_test_user",
        "password": "secure_password",
        "session_id": "session123"
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("test-orchestrator", "auth-service-cpp", auth_request));
    
    // Step 2: User data flows to Rust user service
    std::string user_data = R"({
        "user_id": "user123",
        "action": "get_profile",
        "session_id": "session123"
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("auth-service-cpp", "user-service-rust", user_data));
    
    // Step 3: User activity tracked in Go analytics
    std::string activity_event = R"({
        "event_type": "profile_view",
        "user_id": "user123",
        "session_id": "session123",
        "timestamp": 1640995200
    })";
    
    EXPECT_TRUE(SendCrossLanguageRequest("user-service-rust", "analytics-service-go", activity_event));
}

// Test 5: Performance Comparison Across Languages
TEST_F(PolyglotIntegrationTest, PerformanceComparison) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    const int num_requests = 1000;
    const std::string test_payload = R"({"test": "performance", "iteration": 0})";
    
    // Test C++ component performance
    auto cpp_start = std::chrono::high_resolution_clock::now();
    int cpp_successes = 0;
    for (int i = 0; i < num_requests; ++i) {
        std::string payload = test_payload;
        payload.replace(payload.find("0"), 1, std::to_string(i));
        if (SendCrossLanguageRequest("test-client", "auth-service-cpp", payload, 
                                    std::chrono::milliseconds(1000))) {
            cpp_successes++;
        }
    }
    auto cpp_duration = std::chrono::high_resolution_clock::now() - cpp_start;
    
    // Test Rust component performance
    auto rust_start = std::chrono::high_resolution_clock::now();
    int rust_successes = 0;
    for (int i = 0; i < num_requests; ++i) {
        std::string payload = test_payload;
        payload.replace(payload.find("0"), 1, std::to_string(i));
        if (SendCrossLanguageRequest("test-client", "user-service-rust", payload,
                                    std::chrono::milliseconds(1000))) {
            rust_successes++;
        }
    }
    auto rust_duration = std::chrono::high_resolution_clock::now() - rust_start;
    
    // Test Go component performance
    auto go_start = std::chrono::high_resolution_clock::now();
    int go_successes = 0;
    for (int i = 0; i < num_requests; ++i) {
        std::string payload = test_payload;
        payload.replace(payload.find("0"), 1, std::to_string(i));
        if (SendCrossLanguageRequest("test-client", "analytics-service-go", payload,
                                    std::chrono::milliseconds(1000))) {
            go_successes++;
        }
    }
    auto go_duration = std::chrono::high_resolution_clock::now() - go_start;
    
    // Report performance results
    auto cpp_ms = std::chrono::duration_cast<std::chrono::milliseconds>(cpp_duration).count();
    auto rust_ms = std::chrono::duration_cast<std::chrono::milliseconds>(rust_duration).count();
    auto go_ms = std::chrono::duration_cast<std::chrono::milliseconds>(go_duration).count();
    
    std::cout << "\nPerformance Comparison Results:\n";
    std::cout << "C++ Auth Service: " << cpp_successes << "/" << num_requests 
              << " requests in " << cpp_ms << "ms"
              << " (" << (cpp_ms > 0 ? (cpp_successes * 1000 / cpp_ms) : 0) << " req/s)\n";
    std::cout << "Rust User Service: " << rust_successes << "/" << num_requests 
              << " requests in " << rust_ms << "ms"
              << " (" << (rust_ms > 0 ? (rust_successes * 1000 / rust_ms) : 0) << " req/s)\n";
    std::cout << "Go Analytics Service: " << go_successes << "/" << num_requests 
              << " requests in " << go_ms << "ms"
              << " (" << (go_ms > 0 ? (go_successes * 1000 / go_ms) : 0) << " req/s)\n";
    
    // All components should handle at least 80% of requests successfully
    EXPECT_GE(cpp_successes, num_requests * 0.8);
    EXPECT_GE(rust_successes, num_requests * 0.8);
    EXPECT_GE(go_successes, num_requests * 0.8);
}

// Test 6: Error Handling Across Languages
TEST_F(PolyglotIntegrationTest, CrossLanguageErrorHandling) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Test error propagation from C++ to Rust
    std::string invalid_auth = R"({
        "username": "",
        "password": "invalid",
        "malformed": true
    })";
    
    // Should handle errors gracefully without crashing
    bool cpp_error_handled = SendCrossLanguageRequest("test-client", "auth-service-cpp", 
                                                      invalid_auth, std::chrono::milliseconds(2000));
    
    // Test error propagation from Rust to Go
    std::string invalid_user_data = R"({
        "user_id": "nonexistent",
        "action": "invalid_action"
    })";
    
    bool rust_error_handled = SendCrossLanguageRequest("test-client", "user-service-rust", 
                                                       invalid_user_data, std::chrono::milliseconds(2000));
    
    // Test error propagation from Go to C++
    std::string invalid_analytics = R"({
        "invalid_json": "this should fail parsing"
    })";
    
    bool go_error_handled = SendCrossLanguageRequest("test-client", "analytics-service-go", 
                                                     invalid_analytics, std::chrono::milliseconds(2000));
    
    // Error handling should not crash services, but should return appropriate responses
    // (We don't expect these to succeed, but services should remain responsive)
    
    // Verify services are still responsive after error handling
    std::string health_check = R"({"action": "health_check"})";
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "auth-service-cpp", health_check));
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "user-service-rust", health_check));
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "analytics-service-go", health_check));
}

// Test 7: Memory Safety and Resource Management
TEST_F(PolyglotIntegrationTest, MemorySafetyAndResourceManagement) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Test with large payloads to stress memory management
    const size_t large_payload_size = 1024 * 1024; // 1MB
    std::string large_payload(large_payload_size, 'A');
    large_payload = R"({"large_data": ")" + large_payload + R"("})";
    
    // C++ should handle memory efficiently with RAII
    bool cpp_handles_large = SendCrossLanguageRequest("test-client", "auth-service-cpp", 
                                                      large_payload, std::chrono::milliseconds(10000));
    
    // Rust should handle memory safely with ownership model
    bool rust_handles_large = SendCrossLanguageRequest("test-client", "user-service-rust", 
                                                       large_payload, std::chrono::milliseconds(10000));
    
    // Go should handle memory with garbage collection
    bool go_handles_large = SendCrossLanguageRequest("test-client", "analytics-service-go", 
                                                     large_payload, std::chrono::milliseconds(10000));
    
    // All languages should handle large payloads gracefully
    // (May fail due to size limits, but shouldn't crash)
    
    // Verify services remain responsive after large payload processing
    std::string small_payload = R"({"test": "small"})";
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "auth-service-cpp", small_payload));
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "user-service-rust", small_payload));
    EXPECT_TRUE(SendCrossLanguageRequest("test-client", "analytics-service-go", small_payload));
}

// Test 8: Concurrent Cross-Language Operations
TEST_F(PolyglotIntegrationTest, ConcurrentCrossLanguageOperations) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    const int num_concurrent_operations = 100;
    std::vector<std::thread> threads;
    std::atomic<int> successful_operations{0};
    
    // Launch concurrent operations across all language pairs
    for (int i = 0; i < num_concurrent_operations; ++i) {
        threads.emplace_back([this, i, &successful_operations]() {
            std::string payload = R"({"concurrent_test": )" + std::to_string(i) + R"}";
            
            // C++ -> Rust
            if (SendCrossLanguageRequest("auth-service-cpp", "user-service-rust", payload)) {
                successful_operations++;
            }
            
            // Rust -> Go
            if (SendCrossLanguageRequest("user-service-rust", "analytics-service-go", payload)) {
                successful_operations++;
            }
            
            // Go -> C++
            if (SendCrossLanguageRequest("analytics-service-go", "auth-service-cpp", payload)) {
                successful_operations++;
            }
        });
    }
    
    // Wait for all concurrent operations to complete
    for (auto& thread : threads) {
        thread.join();
    }
    
    // Should handle most concurrent operations successfully
    int expected_min_success = num_concurrent_operations * 3 * 0.7; // 70% success rate minimum
    EXPECT_GE(successful_operations.load(), expected_min_success);
    
    std::cout << "\nConcurrent Operations: " << successful_operations.load() 
              << "/" << (num_concurrent_operations * 3) << " successful\n";
}

// Test 9: Service Discovery Across Languages
TEST_F(PolyglotIntegrationTest, ServiceDiscoveryAcrossLanguages) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Test service discovery
    auto services = message_bus_->discover_services();
    
    // Should find all three services
    EXPECT_GE(services.size(), 3);
    
    // Verify each language is represented
    bool has_cpp = false, has_rust = false, has_go = false;
    
    for (const auto& service : services) {
        auto lang_it = service.metadata.find("language");
        if (lang_it != service.metadata.end()) {
            if (lang_it->second == "cpp") has_cpp = true;
            else if (lang_it->second == "rust") has_rust = true;
            else if (lang_it->second == "go") has_go = true;
        }
    }
    
    EXPECT_TRUE(has_cpp) << "C++ service not discovered";
    EXPECT_TRUE(has_rust) << "Rust service not discovered";
    EXPECT_TRUE(has_go) << "Go service not discovered";
}

// Test 10: System-Wide Health Check
TEST_F(PolyglotIntegrationTest, SystemWideHealthCheck) {
    StartComponent("auth-service-cpp", "cpp");
    StartComponent("user-service-rust", "rust");
    StartComponent("analytics-service-go", "go");
    
    // Wait for services to stabilize
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    // Check overall system health
    EXPECT_TRUE(message_bus_->health_check());
    
    // Check individual service health
    auto services = message_bus_->discover_services();
    for (const auto& service : services) {
        EXPECT_TRUE(message_bus_->is_service_healthy(service.service_id))
            << "Service " << service.service_id << " (" << service.metadata.at("language") 
            << ") is not healthy";
    }
    
    // Get system statistics
    auto stats = message_bus_->get_stats();
    std::cout << "\nSystem Statistics:\n";
    std::cout << "Messages sent: " << stats.messages_sent << "\n";
    std::cout << "Messages received: " << stats.messages_received << "\n";
    std::cout << "Active services: " << stats.active_services << "\n";
    std::cout << "Average latency: " << stats.average_latency_ms << "ms\n";
    
    EXPECT_GT(stats.active_services, 0);
    EXPECT_LT(stats.average_latency_ms, 1000.0); // Less than 1 second average latency
}

// Main test runner
int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    
    std::cout << "Running Polyglot Integration Tests\n";
    std::cout << "Testing C++, Rust, and Go component integration\n\n";
    
    return RUN_ALL_TESTS();
}