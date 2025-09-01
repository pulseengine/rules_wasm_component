package main

// WIT-generated bindings for HTTP service component
// These types correspond to the http-service.wit interface

// HttpRequest represents an HTTP request from the WIT interface
type HttpRequest struct {
	Method  string
	Path    string
	Headers map[string]string // Header key-value pairs
	Body    string
}

// HttpResponse represents an HTTP response from the WIT interface
type HttpResponse struct {
	Status  int32
	Headers map[string]string // Header key-value pairs
	Body    string
}

// ServiceInfo represents service metadata from the WIT interface
type ServiceInfo struct {
	Name        string
	Version     string
	Description string
	Endpoints   []string
	Uptime      int64
	Requests    int64
}

// SetExports is a placeholder for WIT export registration
// In a real implementation, this would register the component's exported functions
func SetExports(service interface{}) {
	// This is a placeholder - actual WIT integration happens at the TinyGo level
	// when the wit and world parameters are provided to the go_wasm_component rule
}
