package main

import (
	"fmt"
	"github.com/example/httpservice/bindings"
	"log"
	"net/http"
	"time"
)

// ServiceImpl implements the HTTP service interface
type ServiceImpl struct {
	startTime time.Time
	requests  int64
}

func NewServiceImpl() *ServiceImpl {
	return &ServiceImpl{
		startTime: time.Now(),
		requests:  0,
	}
}

func (s *ServiceImpl) HandleRequest(request bindings.HttpRequest) bindings.HttpResponse {
	s.requests++

	log.Printf("Handling %s request to %s", request.Method, request.Path)

	// Route the request
	switch request.Path {
	case "/":
		return s.handleRoot(request)
	case "/health":
		return s.handleHealth(request)
	case "/stats":
		return s.handleStats(request)
	default:
		return s.handleNotFound(request)
	}
}

func (s *ServiceImpl) handleRoot(request bindings.HttpRequest) bindings.HttpResponse {
	body := `{
		"message": "Welcome to Go WebAssembly HTTP Service",
		"version": "1.0.0",
		"timestamp": "` + time.Now().Format(time.RFC3339) + `"
	}`

	return bindings.HttpResponse{
		Status: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
			"Server":       "Go-WASM-Component/1.0.0",
		},
		Body: body,
	}
}

func (s *ServiceImpl) handleHealth(request bindings.HttpRequest) bindings.HttpResponse {
	uptime := time.Since(s.startTime)

	body := fmt.Sprintf(`{
		"status": "healthy",
		"uptime_seconds": %.0f,
		"requests_served": %d
	}`, uptime.Seconds(), s.requests)

	return bindings.HttpResponse{
		Status: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: body,
	}
}

func (s *ServiceImpl) handleStats(request bindings.HttpRequest) bindings.HttpResponse {
	uptime := time.Since(s.startTime)

	body := fmt.Sprintf(`{
		"service_name": "Go WebAssembly HTTP Service",
		"version": "1.0.0",
		"uptime": {
			"seconds": %.0f,
			"formatted": "%s"
		},
		"requests": {
			"total": %d,
			"rate_per_minute": %.2f
		},
		"started_at": "%s"
	}`,
		uptime.Seconds(),
		uptime.String(),
		s.requests,
		float64(s.requests)/uptime.Minutes(),
		s.startTime.Format(time.RFC3339),
	)

	return bindings.HttpResponse{
		Status: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: body,
	}
}

func (s *ServiceImpl) handleNotFound(request bindings.HttpRequest) bindings.HttpResponse {
	body := fmt.Sprintf(`{
		"error": "Not Found",
		"message": "Path '%s' not found",
		"available_paths": ["/", "/health", "/stats"]
	}`, request.Path)

	return bindings.HttpResponse{
		Status: 404,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: body,
	}
}

func (s *ServiceImpl) GetServiceInfo() bindings.ServiceInfo {
	uptime := time.Since(s.startTime)

	return bindings.ServiceInfo{
		Name:        "Go WebAssembly HTTP Service",
		Version:     "1.0.0",
		Description: "A sample HTTP service built as a WebAssembly component using Go",
		Endpoints:   []string{"/", "/health", "/stats"},
		Uptime:      int64(uptime.Seconds()),
		Requests:    s.requests,
	}
}

func main() {
	service := NewServiceImpl()

	// Initialize the component with our service implementation
	bindings.SetExports(service)

	log.Println("Go WebAssembly HTTP Service component initialized")
}
