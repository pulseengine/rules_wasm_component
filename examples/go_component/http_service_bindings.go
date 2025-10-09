package main

import (
	"fmt"
	"log"
	"time"

	httpservice "example.com/calculator/example/http-service/http-service"
	"go.bytecodealliance.org/cm"
)

// ServiceImpl implements the HTTP service interface
type ServiceImpl struct {
	startTime time.Time
	requests  uint64
}

// Initialize the HTTP service component exports with generated bindings
func init() {
	service := &ServiceImpl{
		startTime: time.Now(),
		requests:  0,
	}

	httpservice.Exports.HandleRequest = func(request httpservice.HTTPRequest) httpservice.HTTPResponse {
		service.requests++
		log.Printf("Handling %s request to %s", request.Method, request.Path)

		// Route the request
		switch request.Path {
		case "/":
			return service.handleRoot(request)
		case "/health":
			return service.handleHealth(request)
		case "/stats":
			return service.handleStats(request)
		default:
			return service.handleNotFound(request)
		}
	}

	httpservice.Exports.GetServiceInfo = func() httpservice.ServiceInfo {
		uptime := time.Since(service.startTime)
		return httpservice.ServiceInfo{
			Name:        "Go WebAssembly HTTP Service",
			Version:     "1.0.0",
			Description: "A sample HTTP service built as a WebAssembly component using Go",
			Endpoints:   cm.ToList([]string{"/", "/health", "/stats"}),
			Uptime:      uint64(uptime.Seconds()),
			Requests:    service.requests,
		}
	}
}

func (s *ServiceImpl) handleRoot(request httpservice.HTTPRequest) httpservice.HTTPResponse {
	body := fmt.Sprintf(`{
		"message": "Welcome to Go WebAssembly HTTP Service",
		"version": "1.0.0",
		"timestamp": "%s"
	}`, time.Now().Format(time.RFC3339))

	return httpservice.HTTPResponse{
		Status: 200,
		Headers: cm.ToList([][2]string{
			{"Content-Type", "application/json"},
			{"Server", "Go-WASM-Component/1.0.0"},
		}),
		Body: body,
	}
}

func (s *ServiceImpl) handleHealth(request httpservice.HTTPRequest) httpservice.HTTPResponse {
	uptime := time.Since(s.startTime)

	body := fmt.Sprintf(`{
		"status": "healthy",
		"uptime_seconds": %.0f,
		"requests_served": %d
	}`, uptime.Seconds(), s.requests)

	return httpservice.HTTPResponse{
		Status: 200,
		Headers: cm.ToList([][2]string{
			{"Content-Type", "application/json"},
		}),
		Body: body,
	}
}

func (s *ServiceImpl) handleStats(request httpservice.HTTPRequest) httpservice.HTTPResponse {
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

	return httpservice.HTTPResponse{
		Status: 200,
		Headers: cm.ToList([][2]string{
			{"Content-Type", "application/json"},
		}),
		Body: body,
	}
}

func (s *ServiceImpl) handleNotFound(request httpservice.HTTPRequest) httpservice.HTTPResponse {
	body := fmt.Sprintf(`{
		"error": "Not Found",
		"message": "Path '%s' not found",
		"available_paths": ["/", "/health", "/stats"]
	}`, request.Path)

	return httpservice.HTTPResponse{
		Status: 404,
		Headers: cm.ToList([][2]string{
			{"Content-Type", "application/json"},
		}),
		Body: body,
	}
}

// Component main - required but empty for WIT components
func main() {
	log.Println("Go WebAssembly HTTP Service component initialized")
}
