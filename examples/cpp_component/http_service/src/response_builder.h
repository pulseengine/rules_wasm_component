#pragma once

#include "http_utils.h"

#ifdef __cplusplus
extern "C" {
#endif

// Response builder structure
typedef struct {
    http_response_t* response;
    size_t headers_capacity;
    size_t body_capacity;

    // Template system
    char** templates;
    size_t template_count;
    size_t template_capacity;

    // Content negotiation
    char* accepted_types[16];
    size_t accepted_count;

    // Configuration
    bool auto_content_length;
    bool auto_date_header;
    bool auto_content_type;

    // Error tracking
    char error_message[256];
} response_builder_t;

// Template variable structure
typedef struct {
    char* name;
    char* value;
} template_var_t;

// Response builder functions

// Create a new response builder
response_builder_t* response_builder_create(void);

// Reset builder for reuse
void response_builder_reset(response_builder_t* builder);

// Free builder and associated resources
void response_builder_free(response_builder_t* builder);

// Basic response building

// Set response status
bool response_set_status(response_builder_t* builder, http_status_t status);

// Add or update response header
bool response_add_header(response_builder_t* builder, const char* name, const char* value);

// Remove response header
bool response_remove_header(response_builder_t* builder, const char* name);

// Set response body (raw bytes)
bool response_set_body(response_builder_t* builder, const uint8_t* body, size_t size);

// Set response body (string)
bool response_set_body_string(response_builder_t* builder, const char* body);

// Append to response body
bool response_append_body(response_builder_t* builder, const uint8_t* data, size_t size);

// Content-specific response builders

// Set JSON response
bool response_set_json(response_builder_t* builder, const char* json);

// Set HTML response
bool response_set_html(response_builder_t* builder, const char* html);

// Set plain text response
bool response_set_text(response_builder_t* builder, const char* text);

// Set XML response
bool response_set_xml(response_builder_t* builder, const char* xml);

// Set binary response
bool response_set_binary(response_builder_t* builder, const uint8_t* data, size_t size,
                        const char* content_type);

// File response (for static file serving)
bool response_set_file(response_builder_t* builder, const char* filepath,
                      const char* content_type);

// Redirect responses
bool response_redirect(response_builder_t* builder, const char* location,
                      bool permanent);

// Error responses

// Set error response with default message
bool response_set_error(response_builder_t* builder, http_status_t status);

// Set error response with custom message
bool response_set_error_message(response_builder_t* builder, http_status_t status,
                               const char* message);

// Set error response with JSON error object
bool response_set_error_json(response_builder_t* builder, http_status_t status,
                            const char* error_code, const char* message);

// Cookie support

// Add Set-Cookie header
bool response_add_cookie(response_builder_t* builder, const char* name,
                        const char* value, const char* path, const char* domain,
                        int max_age, bool secure, bool http_only);

// Delete cookie (set expired)
bool response_delete_cookie(response_builder_t* builder, const char* name,
                           const char* path, const char* domain);

// Template system

// Load template from string
bool response_load_template(response_builder_t* builder, const char* name,
                           const char* template_content);

// Render template with variables
bool response_render_template(response_builder_t* builder, const char* template_name,
                             const template_var_t* variables, size_t var_count);

// Simple variable substitution in string
char* response_substitute_variables(const char* template_str,
                                   const template_var_t* variables, size_t var_count);

// Content negotiation

// Parse Accept header and set preferred content types
bool response_set_accepted_types(response_builder_t* builder, const char* accept_header);

// Get best content type match
const char* response_get_best_content_type(response_builder_t* builder,
                                          const char* available_types[], size_t count);

// Check if content type is acceptable
bool response_is_acceptable_type(response_builder_t* builder, const char* content_type);

// Caching support

// Set cache control headers
bool response_set_cache_control(response_builder_t* builder, const char* directive);

// Set expires header
bool response_set_expires(response_builder_t* builder, time_t expires_time);

// Set etag header
bool response_set_etag(response_builder_t* builder, const char* etag, bool weak);

// Set last modified header
bool response_set_last_modified(response_builder_t* builder, time_t modified_time);

// CORS support

// Set CORS headers for preflight request
bool response_set_cors_preflight(response_builder_t* builder, const char* origin,
                                const char* methods, const char* headers);

// Set basic CORS headers
bool response_set_cors_headers(response_builder_t* builder, const char* origin);

// Security headers

// Set security headers (XSS protection, content type options, etc.)
bool response_set_security_headers(response_builder_t* builder);

// Set Content Security Policy
bool response_set_csp(response_builder_t* builder, const char* policy);

// Compression support

// Check if client accepts compression
bool response_client_accepts_compression(const http_request_t* request,
                                        const char* encoding);

// Set compressed body (if compression is enabled)
bool response_set_compressed_body(response_builder_t* builder, const uint8_t* data,
                                 size_t size, const char* encoding);

// Response finalization

// Finalize response (add automatic headers, validate, etc.)
bool response_finalize(response_builder_t* builder);

// Get the built response
http_response_t* response_get_response(response_builder_t* builder);

// Clone response
http_response_t* response_clone_response(const http_response_t* response);

// Utility functions

// Get response size estimate
size_t response_estimate_size(const response_builder_t* builder);

// Validate response
bool response_validate(const http_response_t* response, char* error_buffer, size_t error_size);

// Convert response to string (for debugging)
char* response_to_string(const http_response_t* response);

// Log response (for debugging)
void response_log(const http_response_t* response, const char* prefix);

// Common response builders (convenience functions)

// Build 200 OK JSON response
http_response_t* build_json_response(const char* json);

// Build 404 Not Found response
http_response_t* build_not_found_response(void);

// Build 500 Internal Server Error response
http_response_t* build_server_error_response(const char* message);

// Build 400 Bad Request response
http_response_t* build_bad_request_response(const char* message);

// Build simple text response
http_response_t* build_text_response(http_status_t status, const char* text);

// Build redirect response
http_response_t* build_redirect_response(const char* location, bool permanent);

// Build options response for CORS preflight
http_response_t* build_options_response(const char* allowed_methods);

// Build health check response
http_response_t* build_health_response(bool healthy, const char* details);

// Response streaming support (for large responses)

// Streaming response structure
typedef struct {
    response_builder_t* builder;
    void (*write_chunk)(const uint8_t* data, size_t size, void* user_data);
    void* user_data;
    bool headers_sent;
    bool finished;
} response_stream_t;

// Create streaming response
response_stream_t* response_stream_create(response_builder_t* builder,
                                         void (*write_chunk)(const uint8_t*, size_t, void*),
                                         void* user_data);

// Send headers for streaming response
bool response_stream_send_headers(response_stream_t* stream);

// Write chunk to streaming response
bool response_stream_write_chunk(response_stream_t* stream, const uint8_t* data, size_t size);

// Finish streaming response
bool response_stream_finish(response_stream_t* stream);

// Free streaming response
void response_stream_free(response_stream_t* stream);

#ifdef __cplusplus
}
#endif
