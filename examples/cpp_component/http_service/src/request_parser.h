#pragma once

#include "http_utils.h"

#ifdef __cplusplus
extern "C" {
#endif

// Request parser state
typedef enum {
    PARSER_STATE_METHOD,
    PARSER_STATE_PATH,
    PARSER_STATE_VERSION,
    PARSER_STATE_HEADER_NAME,
    PARSER_STATE_HEADER_VALUE,
    PARSER_STATE_BODY,
    PARSER_STATE_COMPLETE,
    PARSER_STATE_ERROR
} parser_state_t;

// HTTP parser structure
typedef struct {
    parser_state_t state;
    http_request_t* request;

    // Parsing buffers
    char* buffer;
    size_t buffer_size;
    size_t buffer_capacity;

    // Current parsing position
    size_t position;

    // Temporary storage during parsing
    char* current_header_name;
    size_t headers_capacity;

    // Configuration
    size_t max_header_size;
    size_t max_body_size;

    // Error information
    char error_message[256];
} http_parser_t;

// Parser functions

// Create and initialize a new parser
http_parser_t* http_parser_create(size_t max_header_size, size_t max_body_size);

// Reset parser for reuse
void http_parser_reset(http_parser_t* parser);

// Free parser and associated resources
void http_parser_free(http_parser_t* parser);

// Parse HTTP request data
// Returns: 0 = need more data, 1 = complete, -1 = error
int http_parser_parse(http_parser_t* parser, const char* data, size_t length);

// Get the parsed request (only valid after parse returns 1)
http_request_t* http_parser_get_request(http_parser_t* parser);

// Get error message (only valid after parse returns -1)
const char* http_parser_get_error(http_parser_t* parser);

// Utility parsing functions

// Parse HTTP request line (e.g., "GET /path HTTP/1.1")
bool parse_request_line(const char* line, http_method_t* method, char** path, char** version);

// Parse HTTP header line (e.g., "Content-Type: application/json")
bool parse_header_line(const char* line, char** name, char** value);

// Parse Content-Length header value
bool parse_content_length(const char* value, size_t* length);

// Parse multipart boundary from Content-Type header
char* parse_multipart_boundary(const char* content_type);

// Request validation functions

// Validate HTTP version string
bool is_valid_http_version(const char* version);

// Check if request has required headers
bool validate_request_headers(const http_request_t* request);

// Check if request body size is within limits
bool validate_request_body_size(size_t body_size, size_t max_size);

// Request manipulation functions

// Add or update a header in the request
bool request_set_header(http_request_t* request, const char* name, const char* value);

// Remove a header from the request
bool request_remove_header(http_request_t* request, const char* name);

// Set request body
bool request_set_body(http_request_t* request, const uint8_t* body, size_t size);

// Clone a request
http_request_t* request_clone(const http_request_t* request);

// Multipart form data parsing

// Multipart part structure
typedef struct {
    http_header_t* headers;
    size_t header_count;
    uint8_t* body;
    size_t body_size;
    char* name;          // From Content-Disposition
    char* filename;      // From Content-Disposition (if file upload)
    char* content_type;  // From Content-Type header
} multipart_part_t;

// Parse multipart form data
multipart_part_t* parse_multipart_body(const uint8_t* body, size_t size,
                                       const char* boundary, size_t* part_count);

// Free multipart parts
void free_multipart_parts(multipart_part_t* parts, size_t count);

// URL-encoded form data parsing

// Parse application/x-www-form-urlencoded body
http_header_t* parse_urlencoded_body(const char* body, size_t* param_count);

// JSON request helpers

// Check if request contains JSON body
bool request_is_json(const http_request_t* request);

// Get JSON body as string (returns NULL if not text)
char* request_get_json_string(const http_request_t* request);

// Cookie parsing

// Cookie structure
typedef struct {
    char* name;
    char* value;
    char* domain;
    char* path;
    bool secure;
    bool http_only;
    time_t expires;
} http_cookie_t;

// Parse Cookie header
http_cookie_t* parse_cookie_header(const char* cookie_header, size_t* cookie_count);

// Free cookies
void free_cookies(http_cookie_t* cookies, size_t count);

// Authorization parsing

// Authorization types
typedef enum {
    AUTH_TYPE_NONE,
    AUTH_TYPE_BASIC,
    AUTH_TYPE_BEARER,
    AUTH_TYPE_DIGEST,
    AUTH_TYPE_CUSTOM
} auth_type_t;

// Authorization structure
typedef struct {
    auth_type_t type;
    char* scheme;
    char* credentials;
    char* username;  // For Basic auth
    char* password;  // For Basic auth
    char* token;     // For Bearer auth
} http_auth_t;

// Parse Authorization header
http_auth_t* parse_authorization_header(const char* auth_header);

// Free authorization structure
void free_auth(http_auth_t* auth);

// Request debugging

// Print request details to string
char* request_to_string(const http_request_t* request);

// Log request (for debugging)
void request_log(const http_request_t* request, const char* prefix);

#ifdef __cplusplus
}
#endif
