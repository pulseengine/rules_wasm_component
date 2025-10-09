package main

import (
	"encoding/json"
	"fmt"

	analyticsservice "example.com/multi-component-system/example/analytics-service/analytics-service"
	"github.com/google/uuid"
	"go.bytecodealliance.org/cm"
)

// Simple in-memory analytics service using wit-bindgen-go generated bindings
type AnalyticsService struct {
	eventCount  int
	funnelCount int
}

func init() {
	service := &AnalyticsService{
		eventCount:  0,
		funnelCount: 0,
	}

	analyticsservice.Exports.TrackEvent = func(eventData cm.List[uint8]) bool {
		// Parse event data as JSON
		var event map[string]interface{}
		if err := json.Unmarshal(eventData.Slice(), &event); err != nil {
			fmt.Printf("Error deserializing event: %v\n", err)
			return false
		}

		service.eventCount++
		fmt.Printf("Tracked event #%d\n", service.eventCount)
		return true
	}

	analyticsservice.Exports.GetMetrics = func(timeWindow string) cm.List[uint8] {
		// Simple metrics response
		metrics := map[string]interface{}{
			"time_window": timeWindow,
			"metrics": []map[string]interface{}{
				{
					"metric_name":      "total_events",
					"value":            float64(service.eventCount),
					"count":            service.eventCount,
					"aggregation_type": "count",
				},
			},
		}

		data, _ := json.Marshal(metrics)
		return cm.ToList(data)
	}

	analyticsservice.Exports.CreateFunnel = func(funnelData cm.List[uint8]) string {
		// Parse funnel definition
		var funnel map[string]interface{}
		if err := json.Unmarshal(funnelData.Slice(), &funnel); err != nil {
			fmt.Printf("Error deserializing funnel: %v\n", err)
			return ""
		}

		// Generate funnel ID
		funnelID := uuid.New().String()
		service.funnelCount++

		fmt.Printf("Created funnel: %s\n", funnelID)
		return funnelID
	}

	analyticsservice.Exports.GetFunnelResults = func(funnelID string) cm.List[uint8] {
		// Simple funnel results
		results := map[string]interface{}{
			"funnel_id": funnelID,
			"steps": []map[string]interface{}{
				{
					"step_name":   "step1",
					"event_count": service.eventCount,
				},
			},
		}

		data, _ := json.Marshal(results)
		return cm.ToList(data)
	}

	analyticsservice.Exports.HealthCheck = func() bool {
		return true
	}

	analyticsservice.Exports.GetServiceStats = func() string {
		stats := map[string]interface{}{
			"service_name":   "Go Analytics Service",
			"version":        "1.0.0",
			"total_events":   service.eventCount,
			"total_funnels":  service.funnelCount,
		}

		data, _ := json.Marshal(stats)
		return string(data)
	}
}

func main() {
	fmt.Println("Analytics Service initialized")
}
