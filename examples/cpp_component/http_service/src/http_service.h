#pragma once

#include "http_utils.h"
#include "request_parser.h"
#include "response_builder.h"

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct http_service http_service_t;
typedef struct route_handler route_handler_t;

// Route handler function type
typedef request_result_t (*route_handler_func_t)(const http_request_t* request,
                                                 void* user_data);

// Route handler structure
struct route_handler {
    http_route_t route;
    route_handler_func_t handler;
    void* user_data;
    route_handler_t* next;
};

// HTTP service structure
struct http_service {
    service_config_t config;
    service_stats_t stats;

    // Route management
    route_handler_t* routes;
    size_t route_count;

    // Middleware chain
    route_handler_func_t* middleware;
    size_t middleware_count;
    size_t middleware_capacity;

    // Request parser
    http_parser_t* parser;

    // Service state
    bool initialized;
    bool running;
    uint64_t start_time;

    // Error handling
    route_handler_func_t error_handler;
    void* error_handler_data;

    // Configuration
    size_t max_request_size;
    size_t max_response_size;
    uint32_t default_timeout_ms;

    // Static file serving
    char* static_root;
    bool enable_directory_listing;

    // CORS settings
    char* cors_origins;
    char* cors_methods;
    char* cors_headers;
    bool cors_credentials;

    // Security settings
    bool enable_security_headers;
    char* csp_policy;
    bool require_https;

    // Logging
    bool enable_request_logging;
    void (*log_func)(const char* message, void* user_data);
    void* log_user_data;
};

// Service management functions

// Create new HTTP service
http_service_t* http_service_create(const char* name, const char* version);

// Initialize service with configuration
bool http_service_init(http_service_t* service, const service_config_t* config);

// Start the service
bool http_service_start(http_service_t* service);

// Stop the service
bool http_service_stop(http_service_t* service);

// Free service and all resources
void http_service_free(http_service_t* service);

// Get service configuration
service_config_t* http_service_get_config(http_service_t* service);

// Get service statistics
service_stats_t* http_service_get_stats(http_service_t* service);

// Reset service statistics
void http_service_reset_stats(http_service_t* service);

// Route management functions

// Add route handler
bool http_service_add_route(http_service_t* service, http_method_t method,
                           const char* path_pattern, route_handler_func_t handler,
                           void* user_data);

// Remove route
bool http_service_remove_route(http_service_t* service, http_method_t method,
                              const char* path_pattern);

// Get all routes
http_route_t* http_service_list_routes(http_service_t* service, size_t* count);

// Find matching route for request
route_handler_t* http_service_find_route(http_service_t* service,
                                        const http_request_t* request);

// Middleware management

// Add middleware (executed in order of addition)
bool http_service_add_middleware(http_service_t* service, route_handler_func_t middleware);

// Remove middleware
bool http_service_remove_middleware(http_service_t* service, route_handler_func_t middleware);

// Request processing

// Main request handler (implements WIT interface)
request_result_t http_service_handle_request(http_service_t* service,
                                           const http_request_t* request);

// Process request through middleware chain
request_result_t http_service_process_middleware(http_service_t* service,
                                               const http_request_t* request,
                                               route_handler_func_t final_handler,
                                               void* handler_data);

// Error handling

// Set custom error handler
void http_service_set_error_handler(http_service_t* service,
                                   route_handler_func_t error_handler,
                                   void* user_data);

// Handle error with default or custom handler
request_result_t http_service_handle_error(http_service_t* service,
                                         const http_request_t* request,
                                         http_status_t status,
                                         const char* message);

// Static file serving

// Enable static file serving from directory
bool http_service_enable_static_files(http_service_t* service, const char* root_directory);

// Disable static file serving
void http_service_disable_static_files(http_service_t* service);

// Handle static file request
request_result_t http_service_handle_static_file(http_service_t* service,
                                               const http_request_t* request,
                                               const char* file_path);

// CORS support

// Configure CORS settings
bool http_service_configure_cors(http_service_t* service, const char* origins,
                                const char* methods, const char* headers,
                                bool credentials);

// Handle CORS preflight request
request_result_t http_service_handle_cors_preflight(http_service_t* service,
                                                  const http_request_t* request);

// Add CORS headers to response
bool http_service_add_cors_headers(http_service_t* service, http_response_t* response,
                                  const char* origin);

// Security features

// Enable security headers
void http_service_enable_security_headers(http_service_t* service, bool enable);

// Set Content Security Policy
bool http_service_set_csp_policy(http_service_t* service, const char* policy);

// Enable HTTPS requirement
void http_service_require_https(http_service_t* service, bool require);

// Validate request security
bool http_service_validate_request_security(http_service_t* service,
                                           const http_request_t* request);

// Logging and monitoring

// Enable request logging
void http_service_enable_logging(http_service_t* service, bool enable);

// Set custom log function
void http_service_set_log_function(http_service_t* service,
                                  void (*log_func)(const char*, void*),
                                  void* user_data);

// Log request
void http_service_log_request(http_service_t* service, const http_request_t* request,
                             const http_response_t* response, uint64_t duration_ms);

// Health check

// Perform health check
bool http_service_health_check(http_service_t* service);

// Handle health check request
request_result_t http_service_handle_health_check(http_service_t* service,
                                                const http_request_t* request);

// Utility functions

// Parse query parameters from request
http_header_t* http_service_parse_query_params(const http_request_t* request,
                                              size_t* count);

// Parse form data from request body
http_header_t* http_service_parse_form_data(const http_request_t* request,
                                           size_t* count);

// Get request header value
const char* http_service_get_header(const http_request_t* request, const char* name);

// Check if request accepts content type
bool http_service_accepts_content_type(const http_request_t* request,
                                      const char* content_type);

// Get client IP address
const char* http_service_get_client_ip(const http_request_t* request);

// Built-in handlers

// Default 404 handler
request_result_t http_service_default_404_handler(const http_request_t* request,
                                                void* user_data);

// Default error handler
request_result_t http_service_default_error_handler(const http_request_t* request,
                                                  void* user_data);

// Options handler (for CORS)
request_result_t http_service_options_handler(const http_request_t* request,
                                            void* user_data);

// Health check handler
request_result_t http_service_health_handler(const http_request_t* request,
                                           void* user_data);

// Echo handler (for testing)
request_result_t http_service_echo_handler(const http_request_t* request,
                                         void* user_data);

// WIT interface implementation

// Global service instance for WIT interface
extern http_service_t* global_http_service;

// Initialize global service
bool init_global_http_service(void);

// WIT interface functions (these will be called by generated bindings)
extern request_result_t handle_request(const http_request_t* request);
extern bool add_route(const http_route_t* route);
extern bool remove_route(http_method_t method, const char* path_pattern);
extern http_route_t* list_routes(size_t* count);
extern service_config_t get_config(void);
extern service_stats_t get_stats(void);
extern void reset_stats(void);
extern bool health_check(void);
extern http_header_t* parse_query_string(const char* query, size_t* count);
extern http_response_t build_response(http_status_t status, const char* body,
                                     const http_header_t* headers, size_t header_count);
extern const char* get_content_type(const char* file_extension);
extern bool is_json_request(const http_request_t* request);
extern bool is_form_request(const http_request_t* request);

#ifdef __cplusplus
}
#endif
