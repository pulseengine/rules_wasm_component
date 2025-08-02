#include "response_builder.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

// Create a new response builder
response_builder_t* response_builder_create(void) {
    response_builder_t* builder = calloc(1, sizeof(response_builder_t));
    if (!builder) return NULL;

    builder->response = calloc(1, sizeof(http_response_t));
    if (!builder->response) {
        free(builder);
        return NULL;
    }

    // Set defaults
    builder->auto_content_length = true;
    builder->auto_date_header = true;
    builder->auto_content_type = true;
    builder->response->status = HTTP_STATUS_OK;

    return builder;
}

// Reset builder for reuse
void response_builder_reset(response_builder_t* builder) {
    if (!builder) return;

    http_free_response(builder->response);
    builder->response = calloc(1, sizeof(http_response_t));
    builder->response->status = HTTP_STATUS_OK;

    // Clear templates
    for (size_t i = 0; i < builder->template_count; i++) {
        free(builder->templates[i]);
    }
    builder->template_count = 0;

    // Clear accepted types
    for (size_t i = 0; i < builder->accepted_count; i++) {
        free(builder->accepted_types[i]);
    }
    builder->accepted_count = 0;

    builder->error_message[0] = '\0';
}

// Free builder and associated resources
void response_builder_free(response_builder_t* builder) {
    if (!builder) return;

    http_free_response(builder->response);
    free(builder->response);

    // Free templates
    for (size_t i = 0; i < builder->template_count; i++) {
        free(builder->templates[i]);
    }
    free(builder->templates);

    // Free accepted types
    for (size_t i = 0; i < builder->accepted_count; i++) {
        free(builder->accepted_types[i]);
    }

    free(builder);
}

// Set response status
bool response_set_status(response_builder_t* builder, http_status_t status) {
    if (!builder) return false;

    builder->response->status = status;
    return true;
}

// Add or update response header
bool response_add_header(response_builder_t* builder, const char* name, const char* value) {
    if (!builder || !name || !value) return false;

    return http_add_header(&builder->response->headers,
                          &builder->response->header_count,
                          &builder->headers_capacity, name, value);
}

// Remove response header
bool response_remove_header(response_builder_t* builder, const char* name) {
    if (!builder || !name) return false;

    for (size_t i = 0; i < builder->response->header_count; i++) {
        if (http_strcasecmp(builder->response->headers[i].name, name) == 0) {
            // Free this header
            free(builder->response->headers[i].name);
            free(builder->response->headers[i].value);

            // Shift remaining headers
            for (size_t j = i; j < builder->response->header_count - 1; j++) {
                builder->response->headers[j] = builder->response->headers[j + 1];
            }

            builder->response->header_count--;
            return true;
        }
    }

    return false;
}

// Set response body (raw bytes)
bool response_set_body(response_builder_t* builder, const uint8_t* body, size_t size) {
    if (!builder) return false;

    // Free existing body
    free(builder->response->body);
    builder->response->body = NULL;
    builder->response->body_size = 0;

    if (body && size > 0) {
        builder->response->body = malloc(size);
        if (!builder->response->body) {
            snprintf(builder->error_message, sizeof(builder->error_message),
                     "Failed to allocate body buffer");
            return false;
        }

        memcpy(builder->response->body, body, size);
        builder->response->body_size = size;
    }

    return true;
}

// Set response body (string)
bool response_set_body_string(response_builder_t* builder, const char* body) {
    if (!body) return response_set_body(builder, NULL, 0);

    size_t size = strlen(body);
    return response_set_body(builder, (const uint8_t*)body, size);
}

// Append to response body
bool response_append_body(response_builder_t* builder, const uint8_t* data, size_t size) {
    if (!builder || !data || size == 0) return false;

    size_t new_size = builder->response->body_size + size;
    uint8_t* new_body = realloc(builder->response->body, new_size);
    if (!new_body) {
        snprintf(builder->error_message, sizeof(builder->error_message),
                 "Failed to expand body buffer");
        return false;
    }

    memcpy(new_body + builder->response->body_size, data, size);
    builder->response->body = new_body;
    builder->response->body_size = new_size;

    return true;
}

// Set JSON response
bool response_set_json(response_builder_t* builder, const char* json) {
    if (!response_set_body_string(builder, json)) return false;

    return response_add_header(builder, "Content-Type", "application/json; charset=utf-8");
}

// Set HTML response
bool response_set_html(response_builder_t* builder, const char* html) {
    if (!response_set_body_string(builder, html)) return false;

    return response_add_header(builder, "Content-Type", "text/html; charset=utf-8");
}

// Set plain text response
bool response_set_text(response_builder_t* builder, const char* text) {
    if (!response_set_body_string(builder, text)) return false;

    return response_add_header(builder, "Content-Type", "text/plain; charset=utf-8");
}

// Set XML response
bool response_set_xml(response_builder_t* builder, const char* xml) {
    if (!response_set_body_string(builder, xml)) return false;

    return response_add_header(builder, "Content-Type", "application/xml; charset=utf-8");
}

// Set binary response
bool response_set_binary(response_builder_t* builder, const uint8_t* data, size_t size,
                        const char* content_type) {
    if (!response_set_body(builder, data, size)) return false;

    const char* ct = content_type ? content_type : "application/octet-stream";
    return response_add_header(builder, "Content-Type", ct);
}

// Set redirect response
bool response_redirect(response_builder_t* builder, const char* location, bool permanent) {
    if (!builder || !location) return false;

    http_status_t status = permanent ? HTTP_STATUS_CREATED : HTTP_STATUS_CREATED; // 301 : 302
    response_set_status(builder, status);

    return response_add_header(builder, "Location", location);
}

// Set error response with default message
bool response_set_error(response_builder_t* builder, http_status_t status) {
    const char* message = http_status_to_reason_phrase(status);
    return response_set_error_message(builder, status, message);
}

// Set error response with custom message
bool response_set_error_message(response_builder_t* builder, http_status_t status,
                               const char* message) {
    if (!builder || !message) return false;

    response_set_status(builder, status);

    // Create simple HTML error page
    char error_html[1024];
    snprintf(error_html, sizeof(error_html),
             "<!DOCTYPE html>\n"
             "<html><head><title>%d %s</title></head>\n"
             "<body><h1>%d %s</h1><p>%s</p></body></html>",
             status, http_status_to_reason_phrase(status),
             status, http_status_to_reason_phrase(status),
             message);

    return response_set_html(builder, error_html);
}

// Set error response with JSON error object
bool response_set_error_json(response_builder_t* builder, http_status_t status,
                            const char* error_code, const char* message) {
    if (!builder) return false;

    response_set_status(builder, status);

    char error_json[512];
    snprintf(error_json, sizeof(error_json),
             "{\"error\":{\"code\":\"%s\",\"message\":\"%s\",\"status\":%d}}",
             error_code ? error_code : "UNKNOWN_ERROR",
             message ? message : "An error occurred",
             status);

    return response_set_json(builder, error_json);
}

// Add Set-Cookie header
bool response_add_cookie(response_builder_t* builder, const char* name,
                        const char* value, const char* path, const char* domain,
                        int max_age, bool secure, bool http_only) {
    if (!builder || !name || !value) return false;

    char cookie[1024];
    int offset = snprintf(cookie, sizeof(cookie), "%s=%s", name, value);

    if (path) {
        offset += snprintf(cookie + offset, sizeof(cookie) - offset, "; Path=%s", path);
    }

    if (domain) {
        offset += snprintf(cookie + offset, sizeof(cookie) - offset, "; Domain=%s", domain);
    }

    if (max_age >= 0) {
        offset += snprintf(cookie + offset, sizeof(cookie) - offset, "; Max-Age=%d", max_age);
    }

    if (secure) {
        offset += snprintf(cookie + offset, sizeof(cookie) - offset, "; Secure");
    }

    if (http_only) {
        offset += snprintf(cookie + offset, sizeof(cookie) - offset, "; HttpOnly");
    }

    return response_add_header(builder, "Set-Cookie", cookie);
}

// Delete cookie (set expired)
bool response_delete_cookie(response_builder_t* builder, const char* name,
                           const char* path, const char* domain) {
    return response_add_cookie(builder, name, "", path, domain, 0, false, false);
}

// Simple variable substitution in string
char* response_substitute_variables(const char* template_str,
                                   const template_var_t* variables, size_t var_count) {
    if (!template_str) return NULL;

    size_t template_len = strlen(template_str);
    size_t result_capacity = template_len * 2;
    char* result = malloc(result_capacity);
    if (!result) return NULL;

    size_t result_len = 0;
    const char* pos = template_str;

    while (*pos) {
        if (*pos == '{' && *(pos + 1) == '{') {
            // Find end of variable
            const char* var_start = pos + 2;
            const char* var_end = strstr(var_start, "}}");

            if (var_end) {
                // Extract variable name
                size_t var_name_len = var_end - var_start;
                char var_name[256];
                if (var_name_len < sizeof(var_name)) {
                    strncpy(var_name, var_start, var_name_len);
                    var_name[var_name_len] = '\0';

                    // Find variable value
                    const char* var_value = NULL;
                    for (size_t i = 0; i < var_count; i++) {
                        if (strcmp(variables[i].name, var_name) == 0) {
                            var_value = variables[i].value;
                            break;
                        }
                    }

                    if (var_value) {
                        size_t value_len = strlen(var_value);

                        // Ensure capacity
                        while (result_len + value_len >= result_capacity) {
                            result_capacity *= 2;
                            char* new_result = realloc(result, result_capacity);
                            if (!new_result) {
                                free(result);
                                return NULL;
                            }
                            result = new_result;
                        }

                        // Copy value
                        strcpy(result + result_len, var_value);
                        result_len += value_len;
                    }

                    pos = var_end + 2;
                    continue;
                }
            }
        }

        // Ensure capacity for one more character
        if (result_len >= result_capacity - 1) {
            result_capacity *= 2;
            char* new_result = realloc(result, result_capacity);
            if (!new_result) {
                free(result);
                return NULL;
            }
            result = new_result;
        }

        result[result_len++] = *pos++;
    }

    result[result_len] = '\0';
    return result;
}

// Set cache control headers
bool response_set_cache_control(response_builder_t* builder, const char* directive) {
    return response_add_header(builder, "Cache-Control", directive);
}

// Set expires header
bool response_set_expires(response_builder_t* builder, time_t expires_time) {
    char expires_str[128];
    struct tm* gmt = gmtime(&expires_time);
    strftime(expires_str, sizeof(expires_str), "%a, %d %b %Y %H:%M:%S GMT", gmt);

    return response_add_header(builder, "Expires", expires_str);
}

// Set etag header
bool response_set_etag(response_builder_t* builder, const char* etag, bool weak) {
    if (!builder || !etag) return false;

    char etag_header[256];
    snprintf(etag_header, sizeof(etag_header), "%s\"%s\"", weak ? "W/" : "", etag);

    return response_add_header(builder, "ETag", etag_header);
}

// Set security headers
bool response_set_security_headers(response_builder_t* builder) {
    if (!builder) return false;

    response_add_header(builder, "X-Content-Type-Options", "nosniff");
    response_add_header(builder, "X-Frame-Options", "DENY");
    response_add_header(builder, "X-XSS-Protection", "1; mode=block");
    response_add_header(builder, "Referrer-Policy", "strict-origin-when-cross-origin");

    return true;
}

// Set Content Security Policy
bool response_set_csp(response_builder_t* builder, const char* policy) {
    return response_add_header(builder, "Content-Security-Policy", policy);
}

// Finalize response (add automatic headers, validate, etc.)
bool response_finalize(response_builder_t* builder) {
    if (!builder) return false;

    // Add Content-Length if enabled and not present
    if (builder->auto_content_length) {
        if (!http_find_header(builder->response->headers,
                             builder->response->header_count, "Content-Length")) {
            char length_str[32];
            snprintf(length_str, sizeof(length_str), "%zu", builder->response->body_size);
            response_add_header(builder, "Content-Length", length_str);
        }
    }

    // Add Date header if enabled and not present
    if (builder->auto_date_header) {
        if (!http_find_header(builder->response->headers,
                             builder->response->header_count, "Date")) {
            time_t now = time(NULL);
            char date_str[128];
            struct tm* gmt = gmtime(&now);
            strftime(date_str, sizeof(date_str), "%a, %d %b %Y %H:%M:%S GMT", gmt);
            response_add_header(builder, "Date", date_str);
        }
    }

    // Add Server header if not present
    if (!http_find_header(builder->response->headers,
                         builder->response->header_count, "Server")) {
        response_add_header(builder, "Server", "C HTTP Service Component/1.0");
    }

    return true;
}

// Get the built response
http_response_t* response_get_response(response_builder_t* builder) {
    if (!builder) return NULL;

    return builder->response;
}

// Common response builders (convenience functions)

// Build 200 OK JSON response
http_response_t* build_json_response(const char* json) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_set_json(builder, json);
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build 404 Not Found response
http_response_t* build_not_found_response(void) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_set_error(builder, HTTP_STATUS_NOT_FOUND);
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build 500 Internal Server Error response
http_response_t* build_server_error_response(const char* message) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_set_error_message(builder, HTTP_STATUS_INTERNAL_SERVER_ERROR,
                              message ? message : "Internal Server Error");
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build 400 Bad Request response
http_response_t* build_bad_request_response(const char* message) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_set_error_message(builder, HTTP_STATUS_BAD_REQUEST,
                              message ? message : "Bad Request");
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build simple text response
http_response_t* build_text_response(http_status_t status, const char* text) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_set_status(builder, status);
    response_set_text(builder, text);
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build redirect response
http_response_t* build_redirect_response(const char* location, bool permanent) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    response_redirect(builder, location, permanent);
    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Build health check response
http_response_t* build_health_response(bool healthy, const char* details) {
    response_builder_t* builder = response_builder_create();
    if (!builder) return NULL;

    if (healthy) {
        char health_json[256];
        snprintf(health_json, sizeof(health_json),
                 "{\"status\":\"healthy\",\"details\":\"%s\"}",
                 details ? details : "Service is running");
        response_set_json(builder, health_json);
    } else {
        response_set_status(builder, HTTP_STATUS_SERVICE_UNAVAILABLE);
        char health_json[256];
        snprintf(health_json, sizeof(health_json),
                 "{\"status\":\"unhealthy\",\"details\":\"%s\"}",
                 details ? details : "Service is not available");
        response_set_json(builder, health_json);
    }

    response_finalize(builder);

    http_response_t* response = response_clone_response(builder->response);
    response_builder_free(builder);

    return response;
}

// Clone response
http_response_t* response_clone_response(const http_response_t* response) {
    if (!response) return NULL;

    http_response_t* clone = calloc(1, sizeof(http_response_t));
    if (!clone) return NULL;

    clone->status = response->status;

    // Clone headers
    if (response->header_count > 0) {
        clone->headers = malloc(response->header_count * sizeof(http_header_t));
        if (!clone->headers) {
            free(clone);
            return NULL;
        }

        clone->header_count = response->header_count;
        for (size_t i = 0; i < response->header_count; i++) {
            clone->headers[i].name = http_strdup(response->headers[i].name);
            clone->headers[i].value = http_strdup(response->headers[i].value);

            if (!clone->headers[i].name || !clone->headers[i].value) {
                http_free_response(clone);
                free(clone);
                return NULL;
            }
        }
    }

    // Clone body
    if (response->body_size > 0) {
        clone->body = malloc(response->body_size);
        if (!clone->body) {
            http_free_response(clone);
            free(clone);
            return NULL;
        }

        memcpy(clone->body, response->body, response->body_size);
        clone->body_size = response->body_size;
    }

    return clone;
}
