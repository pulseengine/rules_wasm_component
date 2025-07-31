package main

import (
	"encoding/json"
	"fmt"
	"github.com/example/httpservice/bindings"
	"strconv"
	"strings"
)

// RequestHandler provides utilities for handling HTTP requests
type RequestHandler struct{}

// ParseQueryParams extracts query parameters from a URL path
func (r *RequestHandler) ParseQueryParams(path string) map[string]string {
	params := make(map[string]string)

	if !strings.Contains(path, "?") {
		return params
	}

	parts := strings.Split(path, "?")
	if len(parts) < 2 {
		return params
	}

	queryString := parts[1]
	pairs := strings.Split(queryString, "&")

	for _, pair := range pairs {
		if strings.Contains(pair, "=") {
			kv := strings.Split(pair, "=")
			if len(kv) == 2 {
				params[kv[0]] = kv[1]
			}
		}
	}

	return params
}

// ValidateHeaders checks if required headers are present
func (r *RequestHandler) ValidateHeaders(headers map[string]string, required []string) []string {
	var missing []string

	for _, header := range required {
		if _, exists := headers[header]; !exists {
			missing = append(missing, header)
		}
	}

	return missing
}

// ParseJSONBody attempts to parse a JSON request body into a map
func (r *RequestHandler) ParseJSONBody(body string) (map[string]interface{}, error) {
	var result map[string]interface{}

	if err := json.Unmarshal([]byte(body), &result); err != nil {
		return nil, fmt.Errorf("failed to parse JSON body: %v", err)
	}

	return result, nil
}

// CreateErrorResponse creates a standardized error response
func (r *RequestHandler) CreateErrorResponse(status int, message string, details ...string) bindings.HttpResponse {
	errorData := map[string]interface{}{
		"error":   true,
		"status":  status,
		"message": message,
	}

	if len(details) > 0 {
		errorData["details"] = details
	}

	body, _ := json.Marshal(errorData)

	return bindings.HttpResponse{
		Status: int32(status),
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}
}

// CreateSuccessResponse creates a standardized success response
func (r *RequestHandler) CreateSuccessResponse(data interface{}) bindings.HttpResponse {
	responseData := map[string]interface{}{
		"success": true,
		"data":    data,
	}

	body, _ := json.Marshal(responseData)

	return bindings.HttpResponse{
		Status: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}
}

// GetContentType determines the content type from headers or file extension
func (r *RequestHandler) GetContentType(headers map[string]string, path string) string {
	// Check explicit Content-Type header first
	if contentType, exists := headers["Content-Type"]; exists {
		return contentType
	}

	// Determine from file extension
	if strings.HasSuffix(path, ".json") {
		return "application/json"
	} else if strings.HasSuffix(path, ".html") {
		return "text/html"
	} else if strings.HasSuffix(path, ".css") {
		return "text/css"
	} else if strings.HasSuffix(path, ".js") {
		return "application/javascript"
	}

	return "text/plain"
}

// ExtractNumericParam extracts and validates a numeric parameter
func (r *RequestHandler) ExtractNumericParam(params map[string]string, key string) (float64, error) {
	value, exists := params[key]
	if !exists {
		return 0, fmt.Errorf("parameter '%s' is required", key)
	}

	num, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("parameter '%s' must be a valid number", key)
	}

	return num, nil
}

// BuildRedirectResponse creates an HTTP redirect response
func (r *RequestHandler) BuildRedirectResponse(location string) bindings.HttpResponse {
	return bindings.HttpResponse{
		Status: 302,
		Headers: map[string]string{
			"Location": location,
		},
		Body: fmt.Sprintf("Redirecting to %s", location),
	}
}

// LogRequest logs details about an incoming request
func (r *RequestHandler) LogRequest(request bindings.HttpRequest) {
	fmt.Printf("[REQUEST] %s %s\n", request.Method, request.Path)

	if len(request.Headers) > 0 {
		fmt.Println("[HEADERS]")
		for key, value := range request.Headers {
			fmt.Printf("  %s: %s\n", key, value)
		}
	}

	if request.Body != "" {
		fmt.Printf("[BODY] %s\n", request.Body)
	}
}
