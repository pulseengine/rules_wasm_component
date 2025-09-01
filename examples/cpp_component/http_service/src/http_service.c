#include "http_service.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

// Global service instance for WIT interface
http_service_t* global_http_service = NULL;

// Create new HTTP service
http_service_t* http_service_create(const char* name, const char* version) {
    http_service_t* service = calloc(1, sizeof(http_service_t));
    if (!service) return NULL;

    // Initialize configuration
    service->config.name = http_strdup(name ? name : "HTTP Service");
    service->config.version = http_strdup(version ? version : "1.0.0");
    service->config.max_request_size = HTTP_MAX_BODY_SIZE;
    service->config.timeout_ms = 30000;  // 30 seconds

    // Initialize parser
    service->parser = http_parser_create(HTTP_MAX_HEADER_VALUE_LENGTH, HTTP_MAX_BODY_SIZE);
    if (!service->parser) {
        http_service_free(service);
        return NULL;
    }

    // Set defaults
    service->max_request_size = HTTP_MAX_BODY_SIZE;
    service->max_response_size = HTTP_MAX_BODY_SIZE * 2;
    service->default_timeout_ms = 30000;
    service->enable_security_headers = true;
    service->enable_request_logging = false;

    return service;
}

// Initialize service with configuration
bool http_service_init(http_service_t* service, const service_config_t* config) {
    if (!service) return false;

    if (config) {
        // Update configuration
        free(service->config.name);
        free(service->config.version);

        service->config.name = http_strdup(config->name);
        service->config.version = http_strdup(config->version);
        service->config.max_request_size = config->max_request_size;
        service->config.timeout_ms = config->timeout_ms;

        if (config->supported_methods && config->supported_methods_count > 0) {
            service->config.supported_methods = malloc(config->supported_methods_count * sizeof(http_method_t));
            if (service->config.supported_methods) {
                memcpy(service->config.supported_methods, config->supported_methods,
                       config->supported_methods_count * sizeof(http_method_t));
                service->config.supported_methods_count = config->supported_methods_count;
            }
        }
    }

    service->initialized = true;
    return true;
}

// Start the service
bool http_service_start(http_service_t* service) {
    if (!service || !service->initialized) return false;

    service->running = true;
    service->start_time = http_get_current_time_ms();

    // Reset statistics
    memset(&service->stats, 0, sizeof(service_stats_t));

    return true;
}

// Stop the service
bool http_service_stop(http_service_t* service) {
    if (!service) return false;

    service->running = false;
    return true;
}

// Free service and all resources
void http_service_free(http_service_t* service) {
    if (!service) return;

    // Free configuration
    http_free_config(&service->config);

    // Free routes
    route_handler_t* route = service->routes;
    while (route) {
        route_handler_t* next = route->next;
        http_free_route(&route->route);
        free(route);
        route = next;
    }

    // Free middleware
    free(service->middleware);

    // Free parser
    http_parser_free(service->parser);

    // Free other resources
    free(service->static_root);
    free(service->cors_origins);
    free(service->cors_methods);
    free(service->cors_headers);
    free(service->csp_policy);

    free(service);
}

// Add route handler
bool http_service_add_route(http_service_t* service, http_method_t method,
                           const char* path_pattern, route_handler_func_t handler,
                           void* user_data) {
    if (!service || !path_pattern || !handler) return false;

    route_handler_t* route_handler = calloc(1, sizeof(route_handler_t));
    if (!route_handler) return false;

    route_handler->route.method = method;
    route_handler->route.path_pattern = http_strdup(path_pattern);
    route_handler->route.handler_name = http_strdup("custom");
    route_handler->handler = handler;
    route_handler->user_data = user_data;

    if (!route_handler->route.path_pattern || !route_handler->route.handler_name) {
        http_free_route(&route_handler->route);
        free(route_handler);
        return false;
    }

    // Add to linked list
    route_handler->next = service->routes;
    service->routes = route_handler;
    service->route_count++;

    return true;
}

// Find matching route for request
route_handler_t* http_service_find_route(http_service_t* service,
                                        const http_request_t* request) {
    if (!service || !request) return NULL;

    route_handler_t* route = service->routes;
    while (route) {
        if (route->route.method == request->method &&
            http_path_matches_pattern(request->path, route->route.path_pattern)) {
            return route;
        }
        route = route->next;
    }

    return NULL;
}

// Main request handler
request_result_t http_service_handle_request(http_service_t* service,
                                           const http_request_t* request) {
    if (!service || !request) {
        request_result_t result = {0};
        result.success = false;
        result.error_message = http_strdup("Invalid service or request");
        return result;
    }

    uint64_t start_time = http_get_current_time_ms();
    service->stats.total_requests++;

    // Log request if enabled
    if (service->enable_request_logging) {
        http_service_log_request(service, request, NULL, 0);
    }

    // Validate request security
    if (!http_service_validate_request_security(service, request)) {
        service->stats.failed_requests++;
        return http_service_handle_error(service, request, HTTP_STATUS_FORBIDDEN,
                                       "Request failed security validation");
    }

    // Handle CORS preflight requests
    if (request->method == HTTP_OPTIONS && service->cors_origins) {
        request_result_t result = http_service_handle_cors_preflight(service, request);
        if (result.success) {
            service->stats.successful_requests++;

            // Add CORS headers
            http_service_add_cors_headers(service, &result.response,
                                        http_service_get_header(request, "Origin"));
        } else {
            service->stats.failed_requests++;
        }

        // Update stats
        uint64_t duration = http_get_current_time_ms() - start_time;
        service->stats.average_response_time_ms =
            ((service->stats.average_response_time_ms * (service->stats.total_requests - 1)) + duration) /
            service->stats.total_requests;

        return result;
    }

    // Find matching route
    route_handler_t* route_handler = http_service_find_route(service, request);
    if (!route_handler) {
        // Try static file serving
        if (service->static_root) {
            request_result_t result = http_service_handle_static_file(service, request, request->path);
            if (result.success) {
                service->stats.successful_requests++;

                // Add security headers if enabled
                if (service->enable_security_headers) {
                    response_builder_t* builder = response_builder_create();
                    if (builder) {
                        builder->response = &result.response;
                        response_set_security_headers(builder);
                        builder->response = NULL;  // Don't free it
                        response_builder_free(builder);
                    }
                }

                uint64_t duration = http_get_current_time_ms() - start_time;
                service->stats.average_response_time_ms =
                    ((service->stats.average_response_time_ms * (service->stats.total_requests - 1)) + duration) /
                    service->stats.total_requests;

                return result;
            }
        }

        // No route found, return 404
        service->stats.failed_requests++;
        return http_service_handle_error(service, request, HTTP_STATUS_NOT_FOUND,
                                       "Route not found");
    }

    // Process through middleware chain
    request_result_t result = http_service_process_middleware(service, request,
                                                            route_handler->handler,
                                                            route_handler->user_data);

    if (result.success) {
        service->stats.successful_requests++;

        // Add CORS headers if configured
        if (service->cors_origins) {
            http_service_add_cors_headers(service, &result.response,
                                        http_service_get_header(request, "Origin"));
        }

        // Add security headers if enabled
        if (service->enable_security_headers) {
            response_builder_t* builder = response_builder_create();
            if (builder) {
                builder->response = &result.response;
                response_set_security_headers(builder);
                if (service->csp_policy) {
                    response_set_csp(builder, service->csp_policy);
                }
                builder->response = NULL;  // Don't free it
                response_builder_free(builder);
            }
        }
    } else {
        service->stats.failed_requests++;
    }

    // Update statistics
    uint64_t duration = http_get_current_time_ms() - start_time;
    service->stats.average_response_time_ms =
        ((service->stats.average_response_time_ms * (service->stats.total_requests - 1)) + duration) /
        service->stats.total_requests;

    // Log response if enabled
    if (service->enable_request_logging) {
        http_service_log_request(service, request,
                               result.success ? &result.response : NULL, duration);
    }

    return result;
}

// Process request through middleware chain
request_result_t http_service_process_middleware(http_service_t* service,
                                               const http_request_t* request,
                                               route_handler_func_t final_handler,
                                               void* handler_data) {
    if (!service || !request || !final_handler) {
        request_result_t result = {0};
        result.success = false;
        result.error_message = http_strdup("Invalid middleware parameters");
        return result;
    }

    // If no middleware, call handler directly
    if (service->middleware_count == 0) {
        return final_handler(request, handler_data);
    }

    // TODO: Implement proper middleware chaining
    // For now, just call the final handler
    return final_handler(request, handler_data);
}

// Handle error with default or custom handler
request_result_t http_service_handle_error(http_service_t* service,
                                         const http_request_t* request,
                                         http_status_t status,
                                         const char* message) {
    if (service && service->error_handler) {
        // Use custom error handler
        return service->error_handler(request, service->error_handler_data);
    }

    // Use default error handler
    request_result_t result = {0};
    result.success = true;

    http_response_t* response = build_server_error_response(message);
    if (response) {
        response->status = status;
        result.response = *response;
        free(response);  // Only free the container, not the contents
    } else {
        result.success = false;
        result.error_message = http_strdup("Failed to create error response");
    }

    return result;
}

// Configure CORS settings
bool http_service_configure_cors(http_service_t* service, const char* origins,
                                const char* methods, const char* headers,
                                bool credentials) {
    if (!service) return false;

    free(service->cors_origins);
    free(service->cors_methods);
    free(service->cors_headers);

    service->cors_origins = origins ? http_strdup(origins) : NULL;
    service->cors_methods = methods ? http_strdup(methods) : NULL;
    service->cors_headers = headers ? http_strdup(headers) : NULL;
    service->cors_credentials = credentials;

    return true;
}

// Handle CORS preflight request
request_result_t http_service_handle_cors_preflight(http_service_t* service,
                                                  const http_request_t* request) {
    request_result_t result = {0};
    result.success = true;

    response_builder_t* builder = response_builder_create();
    if (!builder) {
        result.success = false;
        result.error_message = http_strdup("Failed to create response builder");
        return result;
    }

    response_set_status(builder, HTTP_STATUS_NO_CONTENT);

    const char* origin = http_service_get_header(request, "Origin");
    if (origin && service->cors_origins) {
        response_add_header(builder, "Access-Control-Allow-Origin", origin);
    }

    if (service->cors_methods) {
        response_add_header(builder, "Access-Control-Allow-Methods", service->cors_methods);
    }

    if (service->cors_headers) {
        response_add_header(builder, "Access-Control-Allow-Headers", service->cors_headers);
    }

    if (service->cors_credentials) {
        response_add_header(builder, "Access-Control-Allow-Credentials", "true");
    }

    response_add_header(builder, "Access-Control-Max-Age", "86400");  // 24 hours

    response_finalize(builder);
    result.response = *builder->response;

    // Don't free the response data, just the builder
    builder->response = NULL;
    response_builder_free(builder);

    return result;
}

// Add CORS headers to response
bool http_service_add_cors_headers(http_service_t* service, http_response_t* response,
                                  const char* origin) {
    if (!service || !response || !service->cors_origins) return false;

    // Simple implementation - allow all configured origins
    size_t capacity = response->header_count;

    if (origin) {
        http_add_header(&response->headers, &response->header_count, &capacity,
                       "Access-Control-Allow-Origin", origin);
    }

    if (service->cors_credentials) {
        http_add_header(&response->headers, &response->header_count, &capacity,
                       "Access-Control-Allow-Credentials", "true");
    }

    return true;
}

// Validate request security
bool http_service_validate_request_security(http_service_t* service,
                                           const http_request_t* request) {
    if (!service || !request) return false;

    // Check HTTPS requirement
    if (service->require_https) {
        const char* proto = http_service_get_header(request, "X-Forwarded-Proto");
        if (!proto || strcmp(proto, "https") != 0) {
            return false;
        }
    }

    // Validate request size
    if (request->body_size > service->max_request_size) {
        return false;
    }

    // Basic header validation
    return validate_request_headers(request);
}

// Enable request logging
void http_service_enable_logging(http_service_t* service, bool enable) {
    if (service) {
        service->enable_request_logging = enable;
    }
}

// Log request
void http_service_log_request(http_service_t* service, const http_request_t* request,
                             const http_response_t* response, uint64_t duration_ms) {
    if (!service || !request || !service->enable_request_logging) return;

    char log_message[1024];
    snprintf(log_message, sizeof(log_message),
             "%s %s - %d - %llu ms",
             http_method_to_string(request->method),
             request->path,
             response ? response->status : 0,
             (unsigned long long)duration_ms);

    if (service->log_func) {
        service->log_func(log_message, service->log_user_data);
    }
}

// Perform health check
bool http_service_health_check(http_service_t* service) {
    if (!service) return false;

    return service->initialized && service->running;
}

// Get request header value
const char* http_service_get_header(const http_request_t* request, const char* name) {
    if (!request || !name) return NULL;

    http_header_t* header = http_find_header(request->headers, request->header_count, name);
    return header ? header->value : NULL;
}

// Built-in handlers

// Default 404 handler
request_result_t http_service_default_404_handler(const http_request_t* request,
                                                void* user_data) {
    (void)request;  // Unused
    (void)user_data;  // Unused

    request_result_t result = {0};
    result.success = true;

    http_response_t* response = build_not_found_response();
    if (response) {
        result.response = *response;
        free(response);
    } else {
        result.success = false;
        result.error_message = http_strdup("Failed to create 404 response");
    }

    return result;
}

// Health check handler
request_result_t http_service_health_handler(const http_request_t* request,
                                           void* user_data) {
    (void)request;  // Unused

    http_service_t* service = (http_service_t*)user_data;
    bool healthy = http_service_health_check(service);

    request_result_t result = {0};
    result.success = true;

    http_response_t* response = build_health_response(healthy,
                                                     healthy ? "Service is running" : "Service unavailable");
    if (response) {
        result.response = *response;
        free(response);
    } else {
        result.success = false;
        result.error_message = http_strdup("Failed to create health response");
    }

    return result;
}

// Echo handler (for testing)
request_result_t http_service_echo_handler(const http_request_t* request,
                                         void* user_data) {
    (void)user_data;  // Unused

    request_result_t result = {0};
    result.success = true;

    // Create echo response with request details
    char* request_str = request_to_string(request);
    if (request_str) {
        http_response_t* response = build_text_response(HTTP_STATUS_OK, request_str);
        if (response) {
            result.response = *response;
            free(response);
        }
        free(request_str);
    }

    if (!result.response.body) {
        result.success = false;
        result.error_message = http_strdup("Failed to create echo response");
    }

    return result;
}

// Initialize global service
bool init_global_http_service(void) {
    if (global_http_service) {
        return true;  // Already initialized
    }

    global_http_service = http_service_create("Global HTTP Service", "1.0.0");
    if (!global_http_service) {
        return false;
    }

    // Initialize with default configuration
    service_config_t config = {
        .name = "Global HTTP Service",
        .version = "1.0.0",
        .supported_methods = NULL,
        .supported_methods_count = 0,
        .max_request_size = HTTP_MAX_BODY_SIZE,
        .timeout_ms = 30000
    };

    if (!http_service_init(global_http_service, &config)) {
        http_service_free(global_http_service);
        global_http_service = NULL;
        return false;
    }

    if (!http_service_start(global_http_service)) {
        http_service_free(global_http_service);
        global_http_service = NULL;
        return false;
    }

    // Add default routes
    http_service_add_route(global_http_service, HTTP_GET, "/health",
                          http_service_health_handler, global_http_service);
    http_service_add_route(global_http_service, HTTP_GET, "/echo",
                          http_service_echo_handler, NULL);

    return true;
}

// WIT interface functions

extern request_result_t handle_request(const http_request_t* request) {
    if (!global_http_service) {
        if (!init_global_http_service()) {
            request_result_t result = {0};
            result.success = false;
            result.error_message = http_strdup("Service not initialized");
            return result;
        }
    }

    return http_service_handle_request(global_http_service, request);
}

extern service_config_t get_config(void) {
    if (!global_http_service || !init_global_http_service()) {
        service_config_t config = {0};
        return config;
    }

    return global_http_service->config;
}

extern service_stats_t get_stats(void) {
    if (!global_http_service || !init_global_http_service()) {
        service_stats_t stats = {0};
        return stats;
    }

    // Update uptime
    global_http_service->stats.uptime_seconds = http_get_uptime_seconds();

    return global_http_service->stats;
}

extern void reset_stats(void) {
    if (global_http_service) {
        http_service_reset_stats(global_http_service);
    }
}

extern bool health_check(void) {
    if (!global_http_service) {
        return init_global_http_service();
    }

    return http_service_health_check(global_http_service);
}

// Missing helper function implementations

// Handle static file serving
request_result_t http_service_handle_static_file(http_service_t* service,
                                               const http_request_t* request,
                                               const char* file_path) {
    request_result_t result = {0};

    if (!service || !request || !file_path) {
        result.success = false;
        result.error_message = http_strdup("Invalid parameters");
        return result;
    }

    // Simple static file response (placeholder implementation)
    result.success = true;

    http_response_t* response = build_text_response(HTTP_STATUS_OK, "Static file content placeholder");
    if (response) {
        result.response = *response;
        free(response);
    } else {
        result.success = false;
        result.error_message = http_strdup("Failed to create static file response");
    }

    return result;
}

// Reset service statistics
void http_service_reset_stats(http_service_t* service) {
    if (!service) return;

    memset(&service->stats, 0, sizeof(service_stats_t));
}

extern const char* get_content_type(const char* file_extension) {
    return http_get_content_type(file_extension);
}

extern bool is_json_request(const http_request_t* request) {
    return request_is_json(request);
}

extern bool is_form_request(const http_request_t* request) {
    if (!request) return false;

    const char* content_type = http_service_get_header(request, "Content-Type");
    return content_type && http_is_form_content_type(content_type);
}

//
// WIT Binding Implementations - Required by generated bindings
//

// Include generated header for proper type definitions
#include "http_service_world.h"

// Convert internal request to WIT request structure
static void convert_to_wit_request(const http_request_t* internal_req,
                                  exports_example_http_service_http_service_http_request_t* wit_req) {
    if (!internal_req || !wit_req) return;

    // Convert method
    wit_req->method.tag = (uint8_t)internal_req->method;

    // Convert path
    http_service_world_string_set(&wit_req->path, internal_req->path);

    // Convert query (optional)
    if (internal_req->query) {
        wit_req->query.is_some = true;
        http_service_world_string_set(&wit_req->query.val, internal_req->query);
    } else {
        wit_req->query.is_some = false;
    }

    // Convert headers
    wit_req->headers.len = internal_req->header_count;
    if (internal_req->header_count > 0) {
        wit_req->headers.ptr = malloc(sizeof(exports_example_http_service_http_service_http_header_t) * internal_req->header_count);
        for (size_t i = 0; i < internal_req->header_count; i++) {
            http_service_world_string_set(&wit_req->headers.ptr[i].name, internal_req->headers[i].name);
            http_service_world_string_set(&wit_req->headers.ptr[i].value, internal_req->headers[i].value);
        }
    } else {
        wit_req->headers.ptr = NULL;
    }

    // Convert body (optional)
    if (internal_req->body && internal_req->body_size > 0) {
        wit_req->body.is_some = true;
        wit_req->body.val.len = internal_req->body_size;
        wit_req->body.val.ptr = (uint8_t*)internal_req->body;
    } else {
        wit_req->body.is_some = false;
    }
}

// Convert internal result to WIT result structure
static void convert_to_wit_result(const request_result_t* internal_result,
                                exports_example_http_service_http_service_request_result_t* wit_result) {
    if (!internal_result || !wit_result) return;

    if (internal_result->success) {
        wit_result->tag = EXPORTS_EXAMPLE_HTTP_SERVICE_HTTP_SERVICE_REQUEST_RESULT_SUCCESS;

        // Convert response
        wit_result->val.success.status = (uint8_t)internal_result->response.status;

        // Convert headers
        wit_result->val.success.headers.len = internal_result->response.header_count;
        if (internal_result->response.header_count > 0) {
            wit_result->val.success.headers.ptr = malloc(sizeof(exports_example_http_service_http_service_http_header_t) * internal_result->response.header_count);
            for (size_t i = 0; i < internal_result->response.header_count; i++) {
                http_service_world_string_set(&wit_result->val.success.headers.ptr[i].name,
                                            internal_result->response.headers[i].name);
                http_service_world_string_set(&wit_result->val.success.headers.ptr[i].value,
                                            internal_result->response.headers[i].value);
            }
        } else {
            wit_result->val.success.headers.ptr = NULL;
        }

        // Convert body (optional)
        if (internal_result->response.body && internal_result->response.body_size > 0) {
            wit_result->val.success.body.is_some = true;
            wit_result->val.success.body.val.len = internal_result->response.body_size;
            wit_result->val.success.body.val.ptr = (uint8_t*)internal_result->response.body;
        } else {
            wit_result->val.success.body.is_some = false;
        }
    } else {
        wit_result->tag = EXPORTS_EXAMPLE_HTTP_SERVICE_HTTP_SERVICE_REQUEST_RESULT_ERROR;
        http_service_world_string_set(&wit_result->val.error,
                                    internal_result->error_message ? internal_result->error_message : "Unknown error");
    }
}

// WIT binding function implementations

void exports_example_http_service_http_service_handle_request(
    exports_example_http_service_http_service_http_request_t *request,
    exports_example_http_service_http_service_request_result_t *ret) {

    if (!request || !ret) return;

    // Initialize global service if needed
    if (!global_http_service && !init_global_http_service()) {
        ret->tag = EXPORTS_EXAMPLE_HTTP_SERVICE_HTTP_SERVICE_REQUEST_RESULT_ERROR;
        http_service_world_string_set(&ret->val.error, "Service initialization failed");
        return;
    }

    // Create internal request structure (simplified conversion)
    http_request_t internal_req = {0};
    internal_req.method = (http_method_t)request->method.tag;
    internal_req.path = (char*)request->path.ptr; // Note: assumes null-terminated

    // Handle request
    request_result_t result = http_service_handle_request(global_http_service, &internal_req);

    // Convert result
    convert_to_wit_result(&result, ret);
}

bool exports_example_http_service_http_service_add_route(
    exports_example_http_service_http_service_route_t *route) {

    if (!route) return false;

    // Initialize global service if needed
    if (!global_http_service && !init_global_http_service()) {
        return false;
    }

    // Convert and add route (simplified - just return success for now)
    return true;
}

bool exports_example_http_service_http_service_remove_route(
    exports_example_http_service_http_service_http_method_t *method,
    http_service_world_string_t *path_pattern) {

    (void)method; (void)path_pattern; // Unused for now
    return true; // Simplified implementation
}

void exports_example_http_service_http_service_list_routes(
    exports_example_http_service_http_service_list_route_t *ret) {

    if (!ret) return;

    // Return empty list for now
    ret->ptr = NULL;
    ret->len = 0;
}

void exports_example_http_service_http_service_get_config(
    exports_example_http_service_http_service_service_config_t *ret) {

    if (!ret) return;

    // Initialize global service if needed
    if (!global_http_service && !init_global_http_service()) {
        memset(ret, 0, sizeof(*ret));
        return;
    }

    // Convert config
    http_service_world_string_set(&ret->name, global_http_service->config.name);
    http_service_world_string_set(&ret->version, global_http_service->config.version);
    ret->max_request_size = global_http_service->config.max_request_size;
    ret->timeout_ms = global_http_service->config.timeout_ms;

    // Empty supported methods list for now
    ret->supported_methods.ptr = NULL;
    ret->supported_methods.len = 0;
}

void exports_example_http_service_http_service_get_stats(
    exports_example_http_service_http_service_service_stats_t *ret) {

    if (!ret) return;

    // Initialize global service if needed
    if (!global_http_service && !init_global_http_service()) {
        memset(ret, 0, sizeof(*ret));
        return;
    }

    // Convert stats
    ret->total_requests = global_http_service->stats.total_requests;
    ret->successful_requests = global_http_service->stats.successful_requests;
    ret->failed_requests = global_http_service->stats.failed_requests;
    ret->average_response_time_ms = global_http_service->stats.average_response_time_ms;
    ret->uptime_seconds = http_get_uptime_seconds();
}

void exports_example_http_service_http_service_reset_stats(void) {
    if (global_http_service) {
        http_service_reset_stats(global_http_service);
    }
}

bool exports_example_http_service_http_service_health_check(void) {
    if (!global_http_service && !init_global_http_service()) {
        return false;
    }

    return http_service_health_check(global_http_service);
}

void exports_example_http_service_http_service_parse_query_string(
    http_service_world_string_t *query,
    exports_example_http_service_http_service_list_http_header_t *ret) {

    (void)query; // Unused for now
    if (!ret) return;

    // Return empty list for now
    ret->ptr = NULL;
    ret->len = 0;
}

void exports_example_http_service_http_service_build_response(
    exports_example_http_service_http_service_http_status_t status,
    http_service_world_string_t *maybe_body,
    exports_example_http_service_http_service_list_http_header_t *maybe_headers,
    exports_example_http_service_http_service_http_response_t *ret) {

    if (!ret) return;

    ret->status = status;

    // Copy headers if provided
    if (maybe_headers && maybe_headers->ptr && maybe_headers->len > 0) {
        ret->headers = *maybe_headers;
    } else {
        ret->headers.ptr = NULL;
        ret->headers.len = 0;
    }

    // Copy body if provided
    if (maybe_body && maybe_body->ptr && maybe_body->len > 0) {
        ret->body.is_some = true;
        ret->body.val.len = maybe_body->len;
        ret->body.val.ptr = malloc(maybe_body->len);
        if (ret->body.val.ptr) {
            memcpy(ret->body.val.ptr, maybe_body->ptr, maybe_body->len);
        }
    } else {
        ret->body.is_some = false;
    }
}

bool exports_example_http_service_http_service_get_content_type(
    http_service_world_string_t *file_extension,
    http_service_world_string_t *ret) {

    if (!file_extension || !ret) return false;

    // Convert to null-terminated string for internal function
    char* ext = malloc(file_extension->len + 1);
    if (!ext) return false;

    memcpy(ext, file_extension->ptr, file_extension->len);
    ext[file_extension->len] = '\0';

    const char* content_type = http_get_content_type(ext);
    free(ext);

    if (content_type) {
        http_service_world_string_set(ret, content_type);
        return true;
    }

    return false;
}

bool exports_example_http_service_http_service_is_json_request(
    exports_example_http_service_http_service_http_request_t *request) {

    if (!request) return false;

    // Convert to internal request format (simplified check)
    for (size_t i = 0; i < request->headers.len; i++) {
        if (request->headers.ptr[i].name.len == 12 &&
            memcmp(request->headers.ptr[i].name.ptr, "Content-Type", 12) == 0) {
            // Check if value contains "json"
            if (request->headers.ptr[i].value.len >= 4) {
                for (size_t j = 0; j <= request->headers.ptr[i].value.len - 4; j++) {
                    if (memcmp(request->headers.ptr[i].value.ptr + j, "json", 4) == 0) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

bool exports_example_http_service_http_service_is_form_request(
    exports_example_http_service_http_service_http_request_t *request) {

    if (!request) return false;

    // Convert to internal request format (simplified check)
    for (size_t i = 0; i < request->headers.len; i++) {
        if (request->headers.ptr[i].name.len == 12 &&
            memcmp(request->headers.ptr[i].name.ptr, "Content-Type", 12) == 0) {
            // Check if value contains "form"
            if (request->headers.ptr[i].value.len >= 4) {
                for (size_t j = 0; j <= request->headers.ptr[i].value.len - 4; j++) {
                    if (memcmp(request->headers.ptr[i].value.ptr + j, "form", 4) == 0) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}
