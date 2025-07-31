#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>

namespace multi_component_system {

/**
 * Inter-component message bus for WebAssembly component communication
 *
 * Provides asynchronous message passing, event broadcasting, and service
 * discovery for multi-component systems in WebAssembly environments.
 */

// Message types and structures
enum class MessageType {
    REQUEST,
    RESPONSE,
    EVENT,
    BROADCAST,
    SYSTEM,
    HEARTBEAT
};

enum class MessagePriority {
    LOW,
    NORMAL,
    HIGH,
    CRITICAL
};

struct MessageHeader {
    std::string message_id;
    std::string correlation_id;
    std::string sender_id;
    std::string recipient_id;
    MessageType type;
    MessagePriority priority;
    uint64_t timestamp;
    uint32_t ttl_seconds;
    std::unordered_map<std::string, std::string> metadata;
};

struct Message {
    MessageHeader header;
    std::vector<uint8_t> payload;
    size_t size() const { return payload.size(); }
    bool is_expired() const;
};

// Message handler callback types
using MessageHandler = std::function<void(const Message&)>;
using ResponseHandler = std::function<void(const Message&, bool success)>;
using EventHandler = std::function<void(const std::string& event, const Message&)>;

// Service registration and discovery
struct ServiceInfo {
    std::string service_id;
    std::string service_name;
    std::string version;
    std::string endpoint;
    std::vector<std::string> capabilities;
    std::unordered_map<std::string, std::string> metadata;
    uint64_t registered_at;
    uint64_t last_heartbeat;
    bool is_healthy;
};

// Message bus configuration
struct MessageBusConfig {
    size_t max_queue_size;
    size_t max_message_size;
    uint32_t default_ttl_seconds;
    uint32_t heartbeat_interval_seconds;
    uint32_t service_timeout_seconds;
    bool enable_persistence;
    bool enable_compression;
    bool enable_encryption;
    std::string encryption_key;

    MessageBusConfig()
        : max_queue_size(10000), max_message_size(1024 * 1024),
          default_ttl_seconds(300), heartbeat_interval_seconds(30),
          service_timeout_seconds(60), enable_persistence(false),
          enable_compression(false), enable_encryption(false) {}
};

// Message bus statistics
struct MessageBusStats {
    uint64_t messages_sent;
    uint64_t messages_received;
    uint64_t messages_dropped;
    uint64_t messages_expired;
    uint64_t bytes_transferred;
    uint32_t active_services;
    uint32_t queued_messages;
    double average_latency_ms;
    uint64_t uptime_seconds;
};

// Main message bus class
class MessageBus {
public:
    explicit MessageBus(const MessageBusConfig& config = MessageBusConfig());
    ~MessageBus();

    // Lifecycle management
    bool start();
    void stop();
    bool is_running() const { return running_.load(); }

    // Service registration and discovery
    bool register_service(const ServiceInfo& service);
    bool unregister_service(const std::string& service_id);
    bool update_service_heartbeat(const std::string& service_id);
    std::vector<ServiceInfo> discover_services(const std::string& capability = "");
    std::optional<ServiceInfo> get_service(const std::string& service_id);
    bool is_service_healthy(const std::string& service_id);

    // Message sending
    bool send_message(const std::string& recipient_id, const std::vector<uint8_t>& payload,
                     MessageType type = MessageType::REQUEST,
                     MessagePriority priority = MessagePriority::NORMAL);

    bool send_request(const std::string& recipient_id, const std::vector<uint8_t>& payload,
                     ResponseHandler response_handler, uint32_t timeout_seconds = 30);

    bool send_response(const std::string& correlation_id, const std::vector<uint8_t>& payload,
                      bool success = true);

    bool broadcast_event(const std::string& event_name, const std::vector<uint8_t>& payload);

    bool broadcast_message(const std::vector<uint8_t>& payload,
                          const std::vector<std::string>& recipient_filter = {});

    // Message handling registration
    void set_message_handler(MessageHandler handler);
    void set_request_handler(const std::string& request_type, MessageHandler handler);
    void subscribe_to_event(const std::string& event_name, EventHandler handler);
    void unsubscribe_from_event(const std::string& event_name);

    // Queue management
    size_t get_queue_size() const;
    void clear_queue();
    bool set_queue_size_limit(size_t limit);

    // Message filtering and routing
    void add_message_filter(const std::string& filter_name,
                           std::function<bool(const Message&)> filter);
    void remove_message_filter(const std::string& filter_name);

    void add_routing_rule(const std::string& pattern, const std::string& target_service_id);
    void remove_routing_rule(const std::string& pattern);

    // Statistics and monitoring
    MessageBusStats get_stats() const;
    void reset_stats();
    std::vector<Message> get_recent_messages(size_t count = 100) const;

    // Configuration
    void update_config(const MessageBusConfig& config);
    MessageBusConfig get_config() const { return config_; }

    // Health check
    bool health_check() const;
    std::string get_health_status() const;

    // Persistence (if enabled)
    bool save_state(const std::string& filepath) const;
    bool load_state(const std::string& filepath);

    // Advanced features
    bool enable_message_compression(bool enable);
    bool enable_message_encryption(bool enable, const std::string& key);
    void set_message_serializer(std::function<std::vector<uint8_t>(const Message&)> serializer,
                               std::function<Message(const std::vector<uint8_t>&)> deserializer);

private:
    MessageBusConfig config_;
    std::atomic<bool> running_;
    std::atomic<bool> stopping_;

    // Service registry
    std::unordered_map<std::string, ServiceInfo> services_;
    mutable std::mutex services_mutex_;

    // Message queues
    std::queue<Message> message_queue_;
    std::queue<Message> priority_queue_;
    mutable std::mutex queue_mutex_;
    std::condition_variable queue_condition_;

    // Message handlers
    MessageHandler default_message_handler_;
    std::unordered_map<std::string, MessageHandler> request_handlers_;
    std::unordered_map<std::string, std::vector<EventHandler>> event_handlers_;
    mutable std::mutex handlers_mutex_;

    // Pending responses
    struct PendingResponse {
        ResponseHandler handler;
        uint64_t expires_at;
    };
    std::unordered_map<std::string, PendingResponse> pending_responses_;
    mutable std::mutex responses_mutex_;

    // Message filters and routing
    std::unordered_map<std::string, std::function<bool(const Message&)>> message_filters_;
    std::unordered_map<std::string, std::string> routing_rules_;
    mutable std::mutex routing_mutex_;

    // Worker threads
    std::vector<std::thread> worker_threads_;
    std::thread heartbeat_thread_;
    std::thread cleanup_thread_;

    // Statistics
    mutable MessageBusStats stats_;
    mutable std::mutex stats_mutex_;
    uint64_t start_time_;

    // Message history (for debugging)
    std::queue<Message> recent_messages_;
    mutable std::mutex history_mutex_;
    static constexpr size_t MAX_HISTORY_SIZE = 1000;

    // Internal methods
    void worker_thread_main();
    void heartbeat_thread_main();
    void cleanup_thread_main();

    void process_message(const Message& message);
    void route_message(const Message& message);
    bool apply_filters(const Message& message);

    std::string generate_message_id();
    std::string generate_correlation_id();
    uint64_t get_current_timestamp();

    void update_stats(const Message& message, bool sent);
    void add_to_history(const Message& message);
    void cleanup_expired_responses();
    void cleanup_inactive_services();

    // Serialization helpers
    std::vector<uint8_t> serialize_message(const Message& message);
    Message deserialize_message(const std::vector<uint8_t>& data);

    // Compression helpers
    std::vector<uint8_t> compress_payload(const std::vector<uint8_t>& payload);
    std::vector<uint8_t> decompress_payload(const std::vector<uint8_t>& compressed);

    // Encryption helpers
    std::vector<uint8_t> encrypt_payload(const std::vector<uint8_t>& payload);
    std::vector<uint8_t> decrypt_payload(const std::vector<uint8_t>& encrypted);
};

// Utility classes for common patterns

// Request-response client
class RequestResponseClient {
public:
    explicit RequestResponseClient(MessageBus* bus, const std::string& client_id);

    template<typename RequestT, typename ResponseT>
    std::optional<ResponseT> send_request(const std::string& service_id,
                                         const std::string& method,
                                         const RequestT& request,
                                         uint32_t timeout_seconds = 30);

private:
    MessageBus* bus_;
    std::string client_id_;
};

// Event publisher/subscriber
class EventPublisher {
public:
    explicit EventPublisher(MessageBus* bus, const std::string& publisher_id);

    template<typename EventT>
    bool publish_event(const std::string& event_name, const EventT& event_data);

private:
    MessageBus* bus_;
    std::string publisher_id_;
};

class EventSubscriber {
public:
    explicit EventSubscriber(MessageBus* bus, const std::string& subscriber_id);

    template<typename EventT>
    void subscribe(const std::string& event_name,
                  std::function<void(const EventT&)> handler);

    void unsubscribe(const std::string& event_name);

private:
    MessageBus* bus_;
    std::string subscriber_id_;
    std::unordered_map<std::string, std::function<void(const Message&)>> handlers_;
};

// Service mesh integration
class ServiceMesh {
public:
    explicit ServiceMesh(MessageBus* bus);

    // Service discovery
    std::vector<std::string> discover_service_instances(const std::string& service_name);
    std::string select_service_instance(const std::string& service_name,
                                       const std::string& load_balance_strategy = "round_robin");

    // Circuit breaker
    enum class CircuitState {
        CLOSED,
        OPEN,
        HALF_OPEN
    };

    void configure_circuit_breaker(const std::string& service_name,
                                  uint32_t failure_threshold,
                                  uint32_t recovery_timeout_seconds);

    CircuitState get_circuit_state(const std::string& service_name);

    // Health checking
    void enable_health_checks(const std::string& service_name,
                             const std::string& health_endpoint,
                             uint32_t interval_seconds);

private:
    MessageBus* bus_;

    struct CircuitBreakerState {
        CircuitState state;
        uint32_t failure_count;
        uint64_t last_failure_time;
        uint32_t failure_threshold;
        uint32_t recovery_timeout;
    };

    std::unordered_map<std::string, CircuitBreakerState> circuit_breakers_;
    std::unordered_map<std::string, uint32_t> service_instance_counters_;
    mutable std::mutex mesh_mutex_;
};

// Global message bus instance
extern std::unique_ptr<MessageBus> g_message_bus;

// Initialization helper
bool initialize_message_bus(const MessageBusConfig& config = MessageBusConfig());
void shutdown_message_bus();
MessageBus* get_message_bus();

} // namespace multi_component_system
