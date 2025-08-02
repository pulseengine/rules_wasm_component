#include "request_parser.h"
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <time.h>

// Create and initialize a new parser
http_parser_t* http_parser_create(size_t max_header_size, size_t max_body_size) {
    http_parser_t* parser = calloc(1, sizeof(http_parser_t));
    if (!parser) return NULL;

    parser->max_header_size = max_header_size ? max_header_size : HTTP_MAX_HEADER_VALUE_LENGTH;
    parser->max_body_size = max_body_size ? max_body_size : HTTP_MAX_BODY_SIZE;
    parser->state = PARSER_STATE_METHOD;

    parser->request = calloc(1, sizeof(http_request_t));
    if (!parser->request) {
        free(parser);
        return NULL;
    }

    parser->buffer_capacity = 1024;
    parser->buffer = malloc(parser->buffer_capacity);
    if (!parser->buffer) {
        free(parser->request);
        free(parser);
        return NULL;
    }

    return parser;
}

// Reset parser for reuse
void http_parser_reset(http_parser_t* parser) {
    if (!parser) return;

    parser->state = PARSER_STATE_METHOD;
    parser->position = 0;
    parser->buffer_size = 0;

    http_free_request(parser->request);
    parser->request = calloc(1, sizeof(http_request_t));

    free(parser->current_header_name);
    parser->current_header_name = NULL;

    parser->error_message[0] = '\0';
}

// Free parser and associated resources
void http_parser_free(http_parser_t* parser) {
    if (!parser) return;

    http_free_request(parser->request);
    free(parser->request);
    free(parser->buffer);
    free(parser->current_header_name);
    free(parser);
}

// Helper function to find line ending
static const char* find_line_ending(const char* data, size_t length) {
    for (size_t i = 0; i < length - 1; i++) {
        if (data[i] == '\r' && data[i + 1] == '\n') {
            return &data[i];
        }
    }
    return NULL;
}

// Helper function to append to buffer
static bool append_to_buffer(http_parser_t* parser, const char* data, size_t length) {
    if (parser->buffer_size + length > parser->buffer_capacity) {
        size_t new_capacity = parser->buffer_capacity * 2;
        if (new_capacity > parser->max_header_size) {
            new_capacity = parser->max_header_size;
        }

        if (parser->buffer_size + length > new_capacity) {
            snprintf(parser->error_message, sizeof(parser->error_message),
                     "Header too large");
            return false;
        }

        char* new_buffer = realloc(parser->buffer, new_capacity);
        if (!new_buffer) {
            snprintf(parser->error_message, sizeof(parser->error_message),
                     "Memory allocation failed");
            return false;
        }

        parser->buffer = new_buffer;
        parser->buffer_capacity = new_capacity;
    }

    memcpy(parser->buffer + parser->buffer_size, data, length);
    parser->buffer_size += length;
    return true;
}

// Parse HTTP request data
int http_parser_parse(http_parser_t* parser, const char* data, size_t length) {
    if (!parser || !data || length == 0) return -1;

    const char* current = data;
    size_t remaining = length;

    while (remaining > 0 && parser->state != PARSER_STATE_COMPLETE &&
           parser->state != PARSER_STATE_ERROR) {

        switch (parser->state) {
            case PARSER_STATE_METHOD: {
                // Look for space after method
                const char* space = memchr(current, ' ', remaining);
                if (!space) {
                    // Append to buffer and wait for more data
                    if (!append_to_buffer(parser, current, remaining)) {
                        parser->state = PARSER_STATE_ERROR;
                        return -1;
                    }
                    return 0;
                }

                // Complete method parsing
                size_t method_len = space - current;
                if (!append_to_buffer(parser, current, method_len)) {
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                parser->buffer[parser->buffer_size] = '\0';
                parser->request->method = http_string_to_method(parser->buffer);

                // Reset buffer for path
                parser->buffer_size = 0;
                parser->state = PARSER_STATE_PATH;

                // Skip space
                current = space + 1;
                remaining = length - (current - data);
                break;
            }

            case PARSER_STATE_PATH: {
                // Look for space after path
                const char* space = memchr(current, ' ', remaining);
                if (!space) {
                    if (!append_to_buffer(parser, current, remaining)) {
                        parser->state = PARSER_STATE_ERROR;
                        return -1;
                    }
                    return 0;
                }

                // Complete path parsing
                size_t path_len = space - current;
                if (!append_to_buffer(parser, current, path_len)) {
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                parser->buffer[parser->buffer_size] = '\0';

                // Split path and query
                char* query_start = strchr(parser->buffer, '?');
                if (query_start) {
                    *query_start = '\0';
                    parser->request->query = http_strdup(query_start + 1);
                }
                parser->request->path = http_strdup(parser->buffer);

                // Reset buffer for version
                parser->buffer_size = 0;
                parser->state = PARSER_STATE_VERSION;

                current = space + 1;
                remaining = length - (current - data);
                break;
            }

            case PARSER_STATE_VERSION: {
                // Look for line ending
                const char* line_end = find_line_ending(current, remaining);
                if (!line_end) {
                    if (!append_to_buffer(parser, current, remaining)) {
                        parser->state = PARSER_STATE_ERROR;
                        return -1;
                    }
                    return 0;
                }

                // Complete version parsing
                size_t version_len = line_end - current;
                if (!append_to_buffer(parser, current, version_len)) {
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                parser->buffer[parser->buffer_size] = '\0';

                // Validate HTTP version
                if (!is_valid_http_version(parser->buffer)) {
                    snprintf(parser->error_message, sizeof(parser->error_message),
                             "Invalid HTTP version: %s", parser->buffer);
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                // Reset buffer for headers
                parser->buffer_size = 0;
                parser->state = PARSER_STATE_HEADER_NAME;

                current = line_end + 2;  // Skip \r\n
                remaining = length - (current - data);
                break;
            }

            case PARSER_STATE_HEADER_NAME: {
                // Look for line ending
                const char* line_end = find_line_ending(current, remaining);
                if (!line_end) {
                    if (!append_to_buffer(parser, current, remaining)) {
                        parser->state = PARSER_STATE_ERROR;
                        return -1;
                    }
                    return 0;
                }

                size_t line_len = line_end - current;

                // Empty line means end of headers
                if (line_len == 0) {
                    // Check if we expect a body
                    http_header_t* content_length = http_find_header(
                        parser->request->headers,
                        parser->request->header_count,
                        "Content-Length"
                    );

                    if (content_length) {
                        size_t body_size = 0;
                        if (parse_content_length(content_length->value, &body_size)) {
                            if (body_size > 0) {
                                if (body_size > parser->max_body_size) {
                                    snprintf(parser->error_message, sizeof(parser->error_message),
                                             "Body too large: %zu bytes", body_size);
                                    parser->state = PARSER_STATE_ERROR;
                                    return -1;
                                }

                                parser->request->body = malloc(body_size);
                                if (!parser->request->body) {
                                    snprintf(parser->error_message, sizeof(parser->error_message),
                                             "Failed to allocate body buffer");
                                    parser->state = PARSER_STATE_ERROR;
                                    return -1;
                                }
                                parser->request->body_size = body_size;
                                parser->position = 0;
                                parser->state = PARSER_STATE_BODY;
                            } else {
                                parser->state = PARSER_STATE_COMPLETE;
                            }
                        } else {
                            snprintf(parser->error_message, sizeof(parser->error_message),
                                     "Invalid Content-Length");
                            parser->state = PARSER_STATE_ERROR;
                            return -1;
                        }
                    } else {
                        parser->state = PARSER_STATE_COMPLETE;
                    }

                    current = line_end + 2;
                    remaining = length - (current - data);
                    break;
                }

                // Parse header line
                if (!append_to_buffer(parser, current, line_len)) {
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                parser->buffer[parser->buffer_size] = '\0';

                char* name = NULL;
                char* value = NULL;
                if (parse_header_line(parser->buffer, &name, &value)) {
                    size_t capacity = parser->headers_capacity;
                    if (!http_add_header(&parser->request->headers,
                                         &parser->request->header_count,
                                         &capacity, name, value)) {
                        free(name);
                        free(value);
                        snprintf(parser->error_message, sizeof(parser->error_message),
                                 "Failed to add header");
                        parser->state = PARSER_STATE_ERROR;
                        return -1;
                    }
                    parser->headers_capacity = capacity;
                    free(name);
                    free(value);
                } else {
                    snprintf(parser->error_message, sizeof(parser->error_message),
                             "Invalid header line: %s", parser->buffer);
                    parser->state = PARSER_STATE_ERROR;
                    return -1;
                }

                // Reset buffer for next header
                parser->buffer_size = 0;

                current = line_end + 2;
                remaining = length - (current - data);
                break;
            }

            case PARSER_STATE_BODY: {
                size_t bytes_needed = parser->request->body_size - parser->position;
                size_t bytes_to_copy = remaining < bytes_needed ? remaining : bytes_needed;

                memcpy(parser->request->body + parser->position, current, bytes_to_copy);
                parser->position += bytes_to_copy;

                if (parser->position >= parser->request->body_size) {
                    parser->state = PARSER_STATE_COMPLETE;
                }

                current += bytes_to_copy;
                remaining -= bytes_to_copy;
                break;
            }

            default:
                parser->state = PARSER_STATE_ERROR;
                return -1;
        }
    }

    if (parser->state == PARSER_STATE_ERROR) {
        return -1;
    } else if (parser->state == PARSER_STATE_COMPLETE) {
        return 1;
    }

    return 0;  // Need more data
}

// Get the parsed request
http_request_t* http_parser_get_request(http_parser_t* parser) {
    if (!parser || parser->state != PARSER_STATE_COMPLETE) {
        return NULL;
    }
    return parser->request;
}

// Get error message
const char* http_parser_get_error(http_parser_t* parser) {
    if (!parser) return "Invalid parser";
    return parser->error_message;
}

// Parse HTTP request line
bool parse_request_line(const char* line, http_method_t* method, char** path, char** version) {
    if (!line || !method || !path || !version) return false;

    // Find first space
    const char* space1 = strchr(line, ' ');
    if (!space1) return false;

    // Find second space
    const char* space2 = strchr(space1 + 1, ' ');
    if (!space2) return false;

    // Extract method
    size_t method_len = space1 - line;
    char method_str[16];
    if (method_len >= sizeof(method_str)) return false;

    strncpy(method_str, line, method_len);
    method_str[method_len] = '\0';
    *method = http_string_to_method(method_str);

    // Extract path
    size_t path_len = space2 - space1 - 1;
    *path = malloc(path_len + 1);
    if (!*path) return false;

    strncpy(*path, space1 + 1, path_len);
    (*path)[path_len] = '\0';

    // Extract version
    *version = http_strdup(space2 + 1);
    if (!*version) {
        free(*path);
        return false;
    }

    return true;
}

// Parse HTTP header line
bool parse_header_line(const char* line, char** name, char** value) {
    if (!line || !name || !value) return false;

    // Find colon
    const char* colon = strchr(line, ':');
    if (!colon) return false;

    // Extract name
    size_t name_len = colon - line;
    *name = malloc(name_len + 1);
    if (!*name) return false;

    strncpy(*name, line, name_len);
    (*name)[name_len] = '\0';

    // Trim whitespace from name
    char* trimmed_name = http_trim_whitespace(*name);
    if (trimmed_name != *name) {
        memmove(*name, trimmed_name, strlen(trimmed_name) + 1);
    }

    // Extract value (skip colon and leading whitespace)
    const char* value_start = colon + 1;
    while (*value_start && isspace((unsigned char)*value_start)) {
        value_start++;
    }

    *value = http_strdup(value_start);
    if (!*value) {
        free(*name);
        return false;
    }

    // Trim trailing whitespace from value
    char* value_end = *value + strlen(*value) - 1;
    while (value_end > *value && isspace((unsigned char)*value_end)) {
        *value_end = '\0';
        value_end--;
    }

    return true;
}

// Parse Content-Length header value
bool parse_content_length(const char* value, size_t* length) {
    if (!value || !length) return false;

    char* endptr;
    unsigned long val = strtoul(value, &endptr, 10);

    if (*endptr != '\0' || val == 0 && value == endptr) {
        return false;
    }

    *length = (size_t)val;
    return true;
}

// Validate HTTP version string
bool is_valid_http_version(const char* version) {
    if (!version) return false;

    return strcmp(version, "HTTP/1.0") == 0 ||
           strcmp(version, "HTTP/1.1") == 0 ||
           strcmp(version, "HTTP/2.0") == 0;
}

// Check if request has required headers
bool validate_request_headers(const http_request_t* request) {
    if (!request) return false;

    // HTTP/1.1 requires Host header
    if (!http_find_header(request->headers, request->header_count, "Host")) {
        return false;
    }

    return true;
}

// Add or update a header in the request
bool request_set_header(http_request_t* request, const char* name, const char* value) {
    if (!request || !name || !value) return false;

    // Check if header already exists
    for (size_t i = 0; i < request->header_count; i++) {
        if (http_strcasecmp(request->headers[i].name, name) == 0) {
            // Update existing header
            char* new_value = http_strdup(value);
            if (!new_value) return false;

            free(request->headers[i].value);
            request->headers[i].value = new_value;
            return true;
        }
    }

    // Add new header
    size_t capacity = request->header_count;
    return http_add_header(&request->headers, &request->header_count,
                          &capacity, name, value);
}

// Set request body
bool request_set_body(http_request_t* request, const uint8_t* body, size_t size) {
    if (!request || (!body && size > 0)) return false;

    // Free existing body
    free(request->body);
    request->body = NULL;
    request->body_size = 0;

    if (size > 0) {
        request->body = malloc(size);
        if (!request->body) return false;

        memcpy(request->body, body, size);
        request->body_size = size;

        // Update Content-Length header
        char length_str[32];
        snprintf(length_str, sizeof(length_str), "%zu", size);
        request_set_header(request, "Content-Length", length_str);
    }

    return true;
}

// Check if request contains JSON body
bool request_is_json(const http_request_t* request) {
    if (!request) return false;

    http_header_t* content_type = http_find_header(request->headers,
                                                   request->header_count,
                                                   "Content-Type");
    if (!content_type) return false;

    return http_is_json_content_type(content_type->value);
}

// Get JSON body as string
char* request_get_json_string(const http_request_t* request) {
    if (!request || !request->body || request->body_size == 0) {
        return NULL;
    }

    if (!request_is_json(request)) {
        return NULL;
    }

    // Allocate string with null terminator
    char* json = malloc(request->body_size + 1);
    if (!json) return NULL;

    memcpy(json, request->body, request->body_size);
    json[request->body_size] = '\0';

    return json;
}

// Print request details to string
char* request_to_string(const http_request_t* request) {
    if (!request) return NULL;

    // Calculate required size
    size_t size = 256;  // Base size
    size += strlen(request->path) + (request->query ? strlen(request->query) : 0);

    for (size_t i = 0; i < request->header_count; i++) {
        size += strlen(request->headers[i].name) + strlen(request->headers[i].value) + 4;
    }

    size += request->body_size + 100;

    char* str = malloc(size);
    if (!str) return NULL;

    // Format request
    int offset = snprintf(str, size, "%s %s%s%s HTTP/1.1\n",
                         http_method_to_string(request->method),
                         request->path,
                         request->query ? "?" : "",
                         request->query ? request->query : "");

    // Add headers
    for (size_t i = 0; i < request->header_count; i++) {
        offset += snprintf(str + offset, size - offset, "%s: %s\n",
                          request->headers[i].name,
                          request->headers[i].value);
    }

    // Add body info
    if (request->body_size > 0) {
        offset += snprintf(str + offset, size - offset,
                          "\n[Body: %zu bytes]\n", request->body_size);
    }

    return str;
}
