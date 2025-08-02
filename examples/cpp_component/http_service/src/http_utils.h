#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// HTTP method enumeration
typedef enum {
    HTTP_GET = 0,
    HTTP_POST,
    HTTP_PUT,
    HTTP_DELETE,
    HTTP_PATCH,
    HTTP_HEAD,
    HTTP_OPTIONS
} http_method_t;

// HTTP status codes
typedef enum {
    HTTP_STATUS_OK = 200,
    HTTP_STATUS_CREATED = 201,
    HTTP_STATUS_NO_CONTENT = 204,
    HTTP_STATUS_BAD_REQUEST = 400,
    HTTP_STATUS_UNAUTHORIZED = 401,
    HTTP_STATUS_FORBIDDEN = 403,
    HTTP_STATUS_NOT_FOUND = 404,
    HTTP_STATUS_METHOD_NOT_ALLOWED = 405,
    HTTP_STATUS_INTERNAL_SERVER_ERROR = 500,
    HTTP_STATUS_NOT_IMPLEMENTED = 501,
    HTTP_STATUS_SERVICE_UNAVAILABLE = 503
} http_status_t;

// HTTP header structure
typedef struct {
    char* name;
    char* value;
} http_header_t;

// HTTP request structure
typedef struct {
    http_method_t method;
    char* path;
    char* query;
    http_header_t* headers;
    size_t header_count;
    uint8_t* body;
    size_t body_size;
} http_request_t;

// HTTP response structure
typedef struct {
    http_status_t status;
    http_header_t* headers;
    size_t header_count;
    uint8_t* body;
    size_t body_size;
} http_response_t;

// Route structure
typedef struct {
    http_method_t method;
    char* path_pattern;
    char* handler_name;
} http_route_t;

// Service configuration
typedef struct {
    char* name;
    char* version;
    http_method_t* supported_methods;
    size_t supported_methods_count;
    uint32_t max_request_size;
    uint32_t timeout_ms;
} service_config_t;

// Service statistics
typedef struct {
    uint64_t total_requests;
    uint64_t successful_requests;
    uint64_t failed_requests;
    uint32_t average_response_time_ms;
    uint64_t uptime_seconds;
} service_stats_t;

// Result structure for request processing
typedef struct {
    bool success;
    union {
        http_response_t response;
        char* error_message;
    };
} request_result_t;

// Utility functions

// String utilities
char* http_strdup(const char* str);
int http_strcasecmp(const char* s1, const char* s2);
char* http_trim_whitespace(char* str);
void http_to_lowercase(char* str);
void http_to_uppercase(char* str);

// HTTP-specific utilities
const char* http_method_to_string(http_method_t method);
http_method_t http_string_to_method(const char* method_str);
const char* http_status_to_string(http_status_t status);
const char* http_status_to_reason_phrase(http_status_t status);

// Header utilities
http_header_t* http_find_header(const http_header_t* headers, size_t count, const char* name);
bool http_add_header(http_header_t** headers, size_t* count, size_t* capacity,
                    const char* name, const char* value);
void http_free_headers(http_header_t* headers, size_t count);

// Content type utilities
const char* http_get_content_type(const char* file_extension);
bool http_is_json_content_type(const char* content_type);
bool http_is_form_content_type(const char* content_type);
bool http_is_text_content_type(const char* content_type);

// URL utilities
char* http_url_decode(const char* encoded);
char* http_url_encode(const char* decoded);
bool http_parse_query_string(const char* query, http_header_t** params, size_t* count);

// Memory management
void http_free_request(http_request_t* request);
void http_free_response(http_response_t* response);
void http_free_route(http_route_t* route);
void http_free_config(service_config_t* config);

// Validation utilities
bool http_is_valid_method(http_method_t method);
bool http_is_valid_path(const char* path);
bool http_is_valid_header_name(const char* name);
bool http_is_valid_header_value(const char* value);

// Pattern matching for routes
bool http_path_matches_pattern(const char* path, const char* pattern);
char** http_extract_path_params(const char* path, const char* pattern, size_t* count);
void http_free_path_params(char** params, size_t count);

// Time utilities (for statistics)
uint64_t http_get_current_time_ms(void);
uint64_t http_get_uptime_seconds(void);

// Error handling
#define HTTP_MAX_ERROR_MESSAGE 512
extern char http_last_error[HTTP_MAX_ERROR_MESSAGE];
void http_set_error(const char* format, ...);
const char* http_get_last_error(void);

// Constants
#define HTTP_MAX_HEADER_COUNT 64
#define HTTP_MAX_HEADER_NAME_LENGTH 256
#define HTTP_MAX_HEADER_VALUE_LENGTH 8192
#define HTTP_MAX_PATH_LENGTH 2048
#define HTTP_MAX_QUERY_LENGTH 4096
#define HTTP_MAX_BODY_SIZE (1024 * 1024)  // 1MB default

#ifdef __cplusplus
}
#endif
