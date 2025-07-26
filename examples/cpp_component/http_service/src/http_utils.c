#include "http_utils.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <time.h>

// Error handling
char http_last_error[HTTP_MAX_ERROR_MESSAGE] = {0};

void http_set_error(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(http_last_error, HTTP_MAX_ERROR_MESSAGE, format, args);
    va_end(args);
}

const char* http_get_last_error(void) {
    return http_last_error;
}

// String utilities
char* http_strdup(const char* str) {
    if (!str) return NULL;
    size_t len = strlen(str);
    char* copy = malloc(len + 1);
    if (copy) {
        strcpy(copy, str);
    }
    return copy;
}

int http_strcasecmp(const char* s1, const char* s2) {
    if (!s1 || !s2) return (s1 == s2) ? 0 : (s1 ? 1 : -1);
    
    while (*s1 && *s2) {
        int diff = tolower((unsigned char)*s1) - tolower((unsigned char)*s2);
        if (diff != 0) return diff;
        s1++;
        s2++;
    }
    return tolower((unsigned char)*s1) - tolower((unsigned char)*s2);
}

char* http_trim_whitespace(char* str) {
    if (!str) return NULL;
    
    // Trim leading whitespace
    while (isspace((unsigned char)*str)) str++;
    
    if (*str == 0) return str;
    
    // Trim trailing whitespace
    char* end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    
    end[1] = '\0';
    return str;
}

void http_to_lowercase(char* str) {
    if (!str) return;
    for (; *str; str++) {
        *str = tolower((unsigned char)*str);
    }
}

void http_to_uppercase(char* str) {
    if (!str) return;
    for (; *str; str++) {
        *str = toupper((unsigned char)*str);
    }
}

// HTTP method conversions
const char* http_method_to_string(http_method_t method) {
    switch (method) {
        case HTTP_GET:     return "GET";
        case HTTP_POST:    return "POST";
        case HTTP_PUT:     return "PUT";
        case HTTP_DELETE:  return "DELETE";
        case HTTP_PATCH:   return "PATCH";
        case HTTP_HEAD:    return "HEAD";
        case HTTP_OPTIONS: return "OPTIONS";
        default:           return "UNKNOWN";
    }
}

http_method_t http_string_to_method(const char* method_str) {
    if (!method_str) return HTTP_GET;
    
    if (http_strcasecmp(method_str, "GET") == 0) return HTTP_GET;
    if (http_strcasecmp(method_str, "POST") == 0) return HTTP_POST;
    if (http_strcasecmp(method_str, "PUT") == 0) return HTTP_PUT;
    if (http_strcasecmp(method_str, "DELETE") == 0) return HTTP_DELETE;
    if (http_strcasecmp(method_str, "PATCH") == 0) return HTTP_PATCH;
    if (http_strcasecmp(method_str, "HEAD") == 0) return HTTP_HEAD;
    if (http_strcasecmp(method_str, "OPTIONS") == 0) return HTTP_OPTIONS;
    
    return HTTP_GET;  // Default
}

// HTTP status conversions
const char* http_status_to_string(http_status_t status) {
    static char buffer[16];
    snprintf(buffer, sizeof(buffer), "%d", status);
    return buffer;
}

const char* http_status_to_reason_phrase(http_status_t status) {
    switch (status) {
        case HTTP_STATUS_OK:                    return "OK";
        case HTTP_STATUS_CREATED:               return "Created";
        case HTTP_STATUS_NO_CONTENT:            return "No Content";
        case HTTP_STATUS_BAD_REQUEST:           return "Bad Request";
        case HTTP_STATUS_UNAUTHORIZED:          return "Unauthorized";
        case HTTP_STATUS_FORBIDDEN:             return "Forbidden";
        case HTTP_STATUS_NOT_FOUND:             return "Not Found";
        case HTTP_STATUS_METHOD_NOT_ALLOWED:    return "Method Not Allowed";
        case HTTP_STATUS_INTERNAL_SERVER_ERROR: return "Internal Server Error";
        case HTTP_STATUS_NOT_IMPLEMENTED:       return "Not Implemented";
        case HTTP_STATUS_SERVICE_UNAVAILABLE:   return "Service Unavailable";
        default:                                return "Unknown";
    }
}

// Header utilities
http_header_t* http_find_header(const http_header_t* headers, size_t count, const char* name) {
    if (!headers || !name) return NULL;
    
    for (size_t i = 0; i < count; i++) {
        if (http_strcasecmp(headers[i].name, name) == 0) {
            return (http_header_t*)&headers[i];
        }
    }
    return NULL;
}

bool http_add_header(http_header_t** headers, size_t* count, size_t* capacity, 
                    const char* name, const char* value) {
    if (!headers || !count || !capacity || !name || !value) return false;
    
    // Check if we need to resize
    if (*count >= *capacity) {
        size_t new_capacity = (*capacity == 0) ? 8 : (*capacity * 2);
        if (new_capacity > HTTP_MAX_HEADER_COUNT) {
            http_set_error("Maximum header count exceeded");
            return false;
        }
        
        http_header_t* new_headers = realloc(*headers, new_capacity * sizeof(http_header_t));
        if (!new_headers) {
            http_set_error("Failed to allocate memory for headers");
            return false;
        }
        
        *headers = new_headers;
        *capacity = new_capacity;
    }
    
    // Add new header
    (*headers)[*count].name = http_strdup(name);
    (*headers)[*count].value = http_strdup(value);
    
    if (!(*headers)[*count].name || !(*headers)[*count].value) {
        free((*headers)[*count].name);
        free((*headers)[*count].value);
        http_set_error("Failed to allocate memory for header strings");
        return false;
    }
    
    (*count)++;
    return true;
}

void http_free_headers(http_header_t* headers, size_t count) {
    if (!headers) return;
    
    for (size_t i = 0; i < count; i++) {
        free(headers[i].name);
        free(headers[i].value);
    }
    free(headers);
}

// Content type utilities
const char* http_get_content_type(const char* file_extension) {
    if (!file_extension) return "application/octet-stream";
    
    // Convert to lowercase for comparison
    char ext[32];
    size_t i;
    for (i = 0; i < sizeof(ext) - 1 && file_extension[i]; i++) {
        ext[i] = tolower((unsigned char)file_extension[i]);
    }
    ext[i] = '\0';
    
    // Common content types
    if (strcmp(ext, "html") == 0 || strcmp(ext, "htm") == 0) return "text/html";
    if (strcmp(ext, "css") == 0) return "text/css";
    if (strcmp(ext, "js") == 0) return "application/javascript";
    if (strcmp(ext, "json") == 0) return "application/json";
    if (strcmp(ext, "xml") == 0) return "application/xml";
    if (strcmp(ext, "txt") == 0) return "text/plain";
    if (strcmp(ext, "png") == 0) return "image/png";
    if (strcmp(ext, "jpg") == 0 || strcmp(ext, "jpeg") == 0) return "image/jpeg";
    if (strcmp(ext, "gif") == 0) return "image/gif";
    if (strcmp(ext, "svg") == 0) return "image/svg+xml";
    if (strcmp(ext, "ico") == 0) return "image/x-icon";
    if (strcmp(ext, "pdf") == 0) return "application/pdf";
    if (strcmp(ext, "zip") == 0) return "application/zip";
    if (strcmp(ext, "wasm") == 0) return "application/wasm";
    
    return "application/octet-stream";
}

bool http_is_json_content_type(const char* content_type) {
    if (!content_type) return false;
    return strstr(content_type, "application/json") != NULL;
}

bool http_is_form_content_type(const char* content_type) {
    if (!content_type) return false;
    return strstr(content_type, "application/x-www-form-urlencoded") != NULL ||
           strstr(content_type, "multipart/form-data") != NULL;
}

bool http_is_text_content_type(const char* content_type) {
    if (!content_type) return false;
    return strstr(content_type, "text/") != NULL ||
           http_is_json_content_type(content_type) ||
           strstr(content_type, "application/xml") != NULL;
}

// URL utilities
static int hex_to_int(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

char* http_url_decode(const char* encoded) {
    if (!encoded) return NULL;
    
    size_t len = strlen(encoded);
    char* decoded = malloc(len + 1);
    if (!decoded) return NULL;
    
    size_t j = 0;
    for (size_t i = 0; i < len; i++) {
        if (encoded[i] == '%' && i + 2 < len) {
            int high = hex_to_int(encoded[i + 1]);
            int low = hex_to_int(encoded[i + 2]);
            if (high >= 0 && low >= 0) {
                decoded[j++] = (char)((high << 4) | low);
                i += 2;
                continue;
            }
        } else if (encoded[i] == '+') {
            decoded[j++] = ' ';
            continue;
        }
        decoded[j++] = encoded[i];
    }
    decoded[j] = '\0';
    
    return decoded;
}

char* http_url_encode(const char* decoded) {
    if (!decoded) return NULL;
    
    // Calculate required length
    size_t len = 0;
    for (const char* p = decoded; *p; p++) {
        if (isalnum((unsigned char)*p) || *p == '-' || *p == '_' || *p == '.' || *p == '~') {
            len++;
        } else {
            len += 3;  // %XX
        }
    }
    
    char* encoded = malloc(len + 1);
    if (!encoded) return NULL;
    
    char* out = encoded;
    for (const char* p = decoded; *p; p++) {
        if (isalnum((unsigned char)*p) || *p == '-' || *p == '_' || *p == '.' || *p == '~') {
            *out++ = *p;
        } else {
            sprintf(out, "%%%02X", (unsigned char)*p);
            out += 3;
        }
    }
    *out = '\0';
    
    return encoded;
}

bool http_parse_query_string(const char* query, http_header_t** params, size_t* count) {
    if (!query || !params || !count) return false;
    
    *params = NULL;
    *count = 0;
    
    char* query_copy = http_strdup(query);
    if (!query_copy) return false;
    
    size_t capacity = 0;
    char* saveptr;
    char* pair = strtok_r(query_copy, "&", &saveptr);
    
    while (pair) {
        char* equals = strchr(pair, '=');
        if (equals) {
            *equals = '\0';
            char* name = http_url_decode(pair);
            char* value = http_url_decode(equals + 1);
            
            if (name && value) {
                http_add_header(params, count, &capacity, name, value);
            }
            
            free(name);
            free(value);
        }
        pair = strtok_r(NULL, "&", &saveptr);
    }
    
    free(query_copy);
    return true;
}

// Memory management
void http_free_request(http_request_t* request) {
    if (!request) return;
    
    free(request->path);
    free(request->query);
    http_free_headers(request->headers, request->header_count);
    free(request->body);
    
    memset(request, 0, sizeof(http_request_t));
}

void http_free_response(http_response_t* response) {
    if (!response) return;
    
    http_free_headers(response->headers, response->header_count);
    free(response->body);
    
    memset(response, 0, sizeof(http_response_t));
}

void http_free_route(http_route_t* route) {
    if (!route) return;
    
    free(route->path_pattern);
    free(route->handler_name);
    
    memset(route, 0, sizeof(http_route_t));
}

void http_free_config(service_config_t* config) {
    if (!config) return;
    
    free(config->name);
    free(config->version);
    free(config->supported_methods);
    
    memset(config, 0, sizeof(service_config_t));
}

// Validation utilities
bool http_is_valid_method(http_method_t method) {
    return method >= HTTP_GET && method <= HTTP_OPTIONS;
}

bool http_is_valid_path(const char* path) {
    if (!path || *path != '/') return false;
    
    // Check for valid characters
    for (const char* p = path; *p; p++) {
        if (!isalnum((unsigned char)*p) && 
            *p != '/' && *p != '-' && *p != '_' && 
            *p != '.' && *p != '~' && *p != '*') {
            return false;
        }
    }
    
    return true;
}

bool http_is_valid_header_name(const char* name) {
    if (!name || !*name) return false;
    
    for (const char* p = name; *p; p++) {
        if (!isalnum((unsigned char)*p) && *p != '-' && *p != '_') {
            return false;
        }
    }
    
    return true;
}

bool http_is_valid_header_value(const char* value) {
    if (!value) return false;
    
    // Check for control characters
    for (const char* p = value; *p; p++) {
        if (iscntrl((unsigned char)*p) && *p != '\t') {
            return false;
        }
    }
    
    return true;
}

// Pattern matching for routes
bool http_path_matches_pattern(const char* path, const char* pattern) {
    if (!path || !pattern) return false;
    
    while (*path && *pattern) {
        if (*pattern == '*') {
            // Skip multiple wildcards
            while (*pattern == '*') pattern++;
            
            // If pattern ends with wildcard, it matches
            if (!*pattern) return true;
            
            // Find next matching segment
            while (*path && *path != *pattern) path++;
            
            if (!*path) return false;
        } else if (*pattern == *path) {
            pattern++;
            path++;
        } else {
            return false;
        }
    }
    
    // Both should be at the end
    return !*path && !*pattern;
}

char** http_extract_path_params(const char* path, const char* pattern, size_t* count) {
    if (!path || !pattern || !count) return NULL;
    
    *count = 0;
    size_t capacity = 4;
    char** params = malloc(capacity * sizeof(char*));
    if (!params) return NULL;
    
    while (*path && *pattern) {
        if (*pattern == '*') {
            // Start of parameter
            const char* param_start = path;
            
            // Skip multiple wildcards
            while (*pattern == '*') pattern++;
            
            // Find end of parameter
            if (*pattern) {
                while (*path && *path != *pattern) path++;
            } else {
                while (*path) path++;
            }
            
            // Extract parameter
            size_t param_len = path - param_start;
            if (param_len > 0) {
                if (*count >= capacity) {
                    capacity *= 2;
                    char** new_params = realloc(params, capacity * sizeof(char*));
                    if (!new_params) {
                        http_free_path_params(params, *count);
                        return NULL;
                    }
                    params = new_params;
                }
                
                params[*count] = malloc(param_len + 1);
                if (params[*count]) {
                    strncpy(params[*count], param_start, param_len);
                    params[*count][param_len] = '\0';
                    (*count)++;
                }
            }
        } else if (*pattern == *path) {
            pattern++;
            path++;
        } else {
            http_free_path_params(params, *count);
            return NULL;
        }
    }
    
    return params;
}

void http_free_path_params(char** params, size_t count) {
    if (!params) return;
    
    for (size_t i = 0; i < count; i++) {
        free(params[i]);
    }
    free(params);
}

// Time utilities
static uint64_t http_start_time = 0;

uint64_t http_get_current_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

uint64_t http_get_uptime_seconds(void) {
    if (http_start_time == 0) {
        http_start_time = http_get_current_time_ms();
    }
    return (http_get_current_time_ms() - http_start_time) / 1000;
}