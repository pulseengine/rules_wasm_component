package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/sync/errgroup"
)

//go:generate wit-bindgen go --out-dir=gen --package-name=analytics wit/analytics_service.wit

// Go Analytics Service Component
//
// Demonstrates Go's concurrency primitives and built-in data processing
// capabilities in a WebAssembly component. This service handles real-time
// analytics, event processing, and statistical computations using goroutines
// and channels for efficient concurrent processing.

// Event processing structures
type Event struct {
	EventID     string                 `json:"event_id"`
	UserID      string                 `json:"user_id"`
	SessionID   string                 `json:"session_id"`
	EventType   string                 `json:"event_type"`
	Timestamp   int64                  `json:"timestamp"`
	Properties  map[string]interface{} `json:"properties"`
	Context     EventContext           `json:"context"`
	ProcessedAt int64                  `json:"processed_at"`
}

type EventContext struct {
	UserAgent  string            `json:"user_agent"`
	IPAddress  string            `json:"ip_address"`
	Referrer   string            `json:"referrer"`
	Page       string            `json:"page"`
	Viewport   Viewport          `json:"viewport"`
	Device     DeviceInfo        `json:"device"`
	Location   LocationInfo      `json:"location"`
	CustomData map[string]string `json:"custom_data"`
}

type Viewport struct {
	Width  int `json:"width"`
	Height int `json:"height"`
}

type DeviceInfo struct {
	Type         string `json:"type"` // "desktop", "mobile", "tablet"
	OS           string `json:"os"`
	Browser      string `json:"browser"`
	Version      string `json:"version"`
	IsMobile     bool   `json:"is_mobile"`
	TouchEnabled bool   `json:"touch_enabled"`
}

type LocationInfo struct {
	Country   string  `json:"country"`
	Region    string  `json:"region"`
	City      string  `json:"city"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
}

// Analytics aggregation structures
type MetricAggregation struct {
	MetricName  string                 `json:"metric_name"`
	Dimensions  map[string]string      `json:"dimensions"`
	TimeWindow  TimeWindow             `json:"time_window"`
	Value       float64                `json:"value"`
	Count       int64                  `json:"count"`
	Aggregation AggregationType        `json:"aggregation"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type TimeWindow struct {
	Start    int64  `json:"start"`
	End      int64  `json:"end"`
	Duration string `json:"duration"` // "1m", "5m", "1h", "1d"
}

type AggregationType string

const (
	AggregationSum     AggregationType = "sum"
	AggregationAverage AggregationType = "average"
	AggregationCount   AggregationType = "count"
	AggregationMin     AggregationType = "min"
	AggregationMax     AggregationType = "max"
	AggregationUnique  AggregationType = "unique"
)

// Funnel analysis structures
type FunnelStep struct {
	StepName     string            `json:"step_name"`
	EventType    string            `json:"event_type"`
	Conditions   map[string]string `json:"conditions"`
	TimeoutHours int               `json:"timeout_hours"`
}

type FunnelAnalysis struct {
	FunnelID    string                 `json:"funnel_id"`
	Name        string                 `json:"name"`
	Steps       []FunnelStep           `json:"steps"`
	Results     []FunnelStepResult     `json:"results"`
	Conversions map[string]int         `json:"conversions"`
	DropoffRate []float64              `json:"dropoff_rate"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type FunnelStepResult struct {
	StepIndex      int     `json:"step_index"`
	UserCount      int     `json:"user_count"`
	ConversionRate float64 `json:"conversion_rate"`
	DropoffCount   int     `json:"dropoff_count"`
	DropoffRate    float64 `json:"dropoff_rate"`
}

// Global service state using Go's concurrency-safe patterns
type AnalyticsService struct {
	mu                sync.RWMutex
	events            []Event
	aggregations      map[string]MetricAggregation
	funnels           map[string]FunnelAnalysis
	eventChannels     map[string]chan Event
	processingWorkers int
	metrics           ServiceMetrics
	isRunning         bool
	shutdown          chan struct{}
	workerGroup       errgroup.Group
}

type ServiceMetrics struct {
	TotalEvents          int64            `json:"total_events"`
	ProcessedEvents      int64            `json:"processed_events"`
	FailedEvents         int64            `json:"failed_events"`
	ActiveGoroutines     int              `json:"active_goroutines"`
	EventTypes           map[string]int64 `json:"event_types"`
	ProcessingLatency    time.Duration    `json:"processing_latency"`
	MemoryUsage          int64            `json:"memory_usage"`
	GoroutinePool        int              `json:"goroutine_pool"`
	ChannelBufferSizes   map[string]int   `json:"channel_buffer_sizes"`
	ConcurrentOperations int64            `json:"concurrent_operations"`
}

// Global service instance
var (
	analyticsService *AnalyticsService
	serviceOnce      sync.Once
)

// Initialize the analytics service with Go's sync.Once pattern
func getAnalyticsService() *AnalyticsService {
	serviceOnce.Do(func() {
		analyticsService = &AnalyticsService{
			events:            make([]Event, 0, 10000),
			aggregations:      make(map[string]MetricAggregation),
			funnels:           make(map[string]FunnelAnalysis),
			eventChannels:     make(map[string]chan Event),
			processingWorkers: 10, // Concurrent goroutines
			metrics: ServiceMetrics{
				EventTypes:         make(map[string]int64),
				ChannelBufferSizes: make(map[string]int),
			},
			isRunning: true,
			shutdown:  make(chan struct{}),
		}

		// Start background processing goroutines
		analyticsService.startProcessingWorkers()
	})
	return analyticsService
}

// Start concurrent event processing workers using goroutines
func (as *AnalyticsService) startProcessingWorkers() {
	// Create buffered channels for different event types
	as.eventChannels["user_actions"] = make(chan Event, 1000)
	as.eventChannels["page_views"] = make(chan Event, 2000)
	as.eventChannels["conversions"] = make(chan Event, 500)
	as.eventChannels["errors"] = make(chan Event, 100)

	// Start worker goroutines for concurrent processing
	for i := 0; i < as.processingWorkers; i++ {
		workerID := i
		as.workerGroup.Go(func() error {
			return as.eventProcessingWorker(workerID)
		})
	}

	// Start aggregation worker
	as.workerGroup.Go(func() error {
		return as.aggregationWorker()
	})

	// Start funnel analysis worker
	as.workerGroup.Go(func() error {
		return as.funnelAnalysisWorker()
	})
}

// Concurrent event processing worker using Go channels
func (as *AnalyticsService) eventProcessingWorker(workerID int) error {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-as.shutdown:
			return nil
		case <-ticker.C:
			// Process events from all channels concurrently
			for channelName, eventChan := range as.eventChannels {
				select {
				case event := <-eventChan:
					as.processEvent(event, workerID, channelName)
				default:
					// Non-blocking channel read
				}
			}
		}
	}
}

// Process individual events with Go's concurrent patterns
func (as *AnalyticsService) processEvent(event Event, workerID int, channelName string) {
	start := time.Now()
	defer func() {
		as.mu.Lock()
		as.metrics.ProcessingLatency = time.Since(start)
		as.metrics.ProcessedEvents++
		as.mu.Unlock()
	}()

	// Concurrent-safe event processing
	as.mu.Lock()
	as.events = append(as.events, event)
	as.metrics.EventTypes[event.EventType]++
	as.metrics.ChannelBufferSizes[channelName] = len(as.eventChannels[channelName])
	as.mu.Unlock()

	// Process event based on type using Go's switch statement
	switch event.EventType {
	case "page_view":
		as.processPageView(event)
	case "user_action":
		as.processUserAction(event)
	case "conversion":
		as.processConversion(event)
	case "error":
		as.processError(event)
	default:
		as.processGenericEvent(event)
	}
}

// Concurrent aggregation processing using goroutines
func (as *AnalyticsService) aggregationWorker() error {
	ticker := time.NewTicker(5 * time.Minute) // Aggregate every 5 minutes
	defer ticker.Stop()

	for {
		select {
		case <-as.shutdown:
			return nil
		case <-ticker.C:
			as.performAggregations()
		}
	}
}

// Perform metric aggregations using Go's concurrency
func (as *AnalyticsService) performAggregations() {
	as.mu.RLock()
	events := make([]Event, len(as.events))
	copy(events, as.events)
	as.mu.RUnlock()

	// Process aggregations concurrently using goroutines
	var wg sync.WaitGroup
	aggregationTypes := []AggregationType{
		AggregationCount, AggregationSum, AggregationAverage,
		AggregationMin, AggregationMax, AggregationUnique,
	}

	for _, aggType := range aggregationTypes {
		wg.Add(1)
		go func(aggregationType AggregationType) {
			defer wg.Done()
			as.calculateAggregation(events, aggregationType)
		}(aggType)
	}

	wg.Wait()
}

// Calculate specific aggregation type with concurrent processing
func (as *AnalyticsService) calculateAggregation(events []Event, aggType AggregationType) {
	now := time.Now()
	timeWindows := []string{"1m", "5m", "1h", "1d"}

	for _, window := range timeWindows {
		duration := parseDuration(window)
		startTime := now.Add(-duration)

		// Filter events for time window using Go's slice operations
		filteredEvents := make([]Event, 0)
		for _, event := range events {
			if time.Unix(event.Timestamp, 0).After(startTime) {
				filteredEvents = append(filteredEvents, event)
			}
		}

		// Group events by dimensions
		dimensionGroups := make(map[string][]Event)
		for _, event := range filteredEvents {
			key := fmt.Sprintf("%s_%s_%s",
				event.EventType,
				event.Context.Device.Type,
				event.Context.Location.Country)
			dimensionGroups[key] = append(dimensionGroups[key], event)
		}

		// Calculate aggregation for each dimension group
		for dimensionKey, groupEvents := range dimensionGroups {
			aggregation := as.calculateMetricValue(groupEvents, aggType)
			aggregationKey := fmt.Sprintf("%s_%s_%s", aggType, window, dimensionKey)

			as.mu.Lock()
			as.aggregations[aggregationKey] = aggregation
			as.mu.Unlock()
		}
	}
}

// Calculate metric values using Go's built-in functions
func (as *AnalyticsService) calculateMetricValue(events []Event, aggType AggregationType) MetricAggregation {
	if len(events) == 0 {
		return MetricAggregation{}
	}

	aggregation := MetricAggregation{
		MetricName:  string(aggType),
		Count:       int64(len(events)),
		Aggregation: aggType,
		TimeWindow: TimeWindow{
			Start: events[0].Timestamp,
			End:   events[len(events)-1].Timestamp,
		},
		Metadata: make(map[string]interface{}),
	}

	// Calculate based on aggregation type using Go's math operations
	switch aggType {
	case AggregationCount:
		aggregation.Value = float64(len(events))
	case AggregationSum:
		sum := 0.0
		for _, event := range events {
			if val, ok := event.Properties["value"].(float64); ok {
				sum += val
			}
		}
		aggregation.Value = sum
	case AggregationAverage:
		sum := 0.0
		count := 0
		for _, event := range events {
			if val, ok := event.Properties["value"].(float64); ok {
				sum += val
				count++
			}
		}
		if count > 0 {
			aggregation.Value = sum / float64(count)
		}
	case AggregationUnique:
		uniqueUsers := make(map[string]bool)
		for _, event := range events {
			uniqueUsers[event.UserID] = true
		}
		aggregation.Value = float64(len(uniqueUsers))
	}

	return aggregation
}

// Funnel analysis worker using Go's concurrent patterns
func (as *AnalyticsService) funnelAnalysisWorker() error {
	ticker := time.NewTicker(10 * time.Minute) // Analyze funnels every 10 minutes
	defer ticker.Stop()

	for {
		select {
		case <-as.shutdown:
			return nil
		case <-ticker.C:
			as.analyzeFunnels()
		}
	}
}

// Analyze conversion funnels using Go's concurrency
func (as *AnalyticsService) analyzeFunnels() {
	as.mu.RLock()
	funnels := make(map[string]FunnelAnalysis)
	for k, v := range as.funnels {
		funnels[k] = v
	}
	events := make([]Event, len(as.events))
	copy(events, as.events)
	as.mu.RUnlock()

	// Process each funnel concurrently
	var wg sync.WaitGroup
	for funnelID, funnel := range funnels {
		wg.Add(1)
		go func(id string, f FunnelAnalysis) {
			defer wg.Done()
			as.processFunnel(id, f, events)
		}(funnelID, funnel)
	}

	wg.Wait()
}

// Process individual funnel with concurrent user tracking
func (as *AnalyticsService) processFunnel(funnelID string, funnel FunnelAnalysis, events []Event) {
	// Group events by user using Go's map operations
	userEvents := make(map[string][]Event)
	for _, event := range events {
		userEvents[event.UserID] = append(userEvents[event.UserID], event)
	}

	// Sort events by timestamp for each user
	for userID := range userEvents {
		sort.Slice(userEvents[userID], func(i, j int) bool {
			return userEvents[userID][i].Timestamp < userEvents[userID][j].Timestamp
		})
	}

	// Analyze funnel steps concurrently
	stepResults := make([]FunnelStepResult, len(funnel.Steps))
	var wg sync.WaitGroup

	for stepIndex, step := range funnel.Steps {
		wg.Add(1)
		go func(index int, funnelStep FunnelStep) {
			defer wg.Done()
			stepResults[index] = as.analyzeFunnelStep(index, funnelStep, userEvents)
		}(stepIndex, step)
	}

	wg.Wait()

	// Update funnel results with concurrent-safe operations
	as.mu.Lock()
	updatedFunnel := funnel
	updatedFunnel.Results = stepResults
	as.funnels[funnelID] = updatedFunnel
	as.mu.Unlock()
}

// Analyze individual funnel step using Go's efficient data processing
func (as *AnalyticsService) analyzeFunnelStep(stepIndex int, step FunnelStep, userEvents map[string][]Event) FunnelStepResult {
	userCount := 0

	// Process users concurrently using goroutines
	userChan := make(chan string, len(userEvents))
	resultChan := make(chan bool, len(userEvents))

	// Send all user IDs to channel
	go func() {
		defer close(userChan)
		for userID := range userEvents {
			userChan <- userID
		}
	}()

	// Process users concurrently
	var wg sync.WaitGroup
	numWorkers := 5

	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for userID := range userChan {
				hasCompleted := as.userCompletedStep(userEvents[userID], step)
				resultChan <- hasCompleted
			}
		}()
	}

	// Close result channel when all workers are done
	go func() {
		wg.Wait()
		close(resultChan)
	}()

	// Count successful completions
	for completed := range resultChan {
		if completed {
			userCount++
		}
	}

	return FunnelStepResult{
		StepIndex:      stepIndex,
		UserCount:      userCount,
		ConversionRate: float64(userCount) / float64(len(userEvents)),
	}
}

// Check if user completed funnel step using Go's string operations
func (as *AnalyticsService) userCompletedStep(events []Event, step FunnelStep) bool {
	for _, event := range events {
		if event.EventType == step.EventType {
			// Check conditions using Go's map operations
			allConditionsMet := true
			for key, expectedValue := range step.Conditions {
				if actualValue, exists := event.Properties[key]; !exists {
					allConditionsMet = false
					break
				} else if fmt.Sprintf("%v", actualValue) != expectedValue {
					allConditionsMet = false
					break
				}
			}
			if allConditionsMet {
				return true
			}
		}
	}
	return false
}

// Event processing methods using Go's efficient patterns
func (as *AnalyticsService) processPageView(event Event) {
	// Concurrent page view analytics
	go func() {
		as.mu.Lock()
		as.metrics.ConcurrentOperations++
		as.mu.Unlock()

		// Process page view metrics
		// Implementation details...

		as.mu.Lock()
		as.metrics.ConcurrentOperations--
		as.mu.Unlock()
	}()
}

func (as *AnalyticsService) processUserAction(event Event) {
	// Concurrent user action processing
	go func() {
		// Implementation details...
	}()
}

func (as *AnalyticsService) processConversion(event Event) {
	// Concurrent conversion tracking
	go func() {
		// Implementation details...
	}()
}

func (as *AnalyticsService) processError(event Event) {
	// Concurrent error analytics
	go func() {
		// Implementation details...
	}()
}

func (as *AnalyticsService) processGenericEvent(event Event) {
	// Generic event processing
}

// Utility functions using Go's standard library
func parseDuration(window string) time.Duration {
	switch window {
	case "1m":
		return time.Minute
	case "5m":
		return 5 * time.Minute
	case "1h":
		return time.Hour
	case "1d":
		return 24 * time.Hour
	default:
		return time.Hour
	}
}

// WIT interface implementation
func TrackEvent(eventData []byte) bool {
	service := getAnalyticsService()

	var event Event
	if err := json.Unmarshal(eventData, &event); err != nil {
		service.mu.Lock()
		service.metrics.FailedEvents++
		service.mu.Unlock()
		return false
	}

	event.EventID = uuid.New().String()
	event.ProcessedAt = time.Now().Unix()

	// Route to appropriate channel based on event type
	channelName := "user_actions" // default
	switch event.EventType {
	case "page_view":
		channelName = "page_views"
	case "conversion":
		channelName = "conversions"
	case "error":
		channelName = "errors"
	}

	// Non-blocking send to channel
	select {
	case service.eventChannels[channelName] <- event:
		service.mu.Lock()
		service.metrics.TotalEvents++
		service.mu.Unlock()
		return true
	default:
		// Channel is full, handle overflow
		service.mu.Lock()
		service.metrics.FailedEvents++
		service.mu.Unlock()
		return false
	}
}

func GetMetrics(timeWindow string) []byte {
	service := getAnalyticsService()

	service.mu.RLock()
	defer service.mu.RUnlock()

	// Filter aggregations by time window
	filteredAggregations := make(map[string]MetricAggregation)
	for key, aggregation := range service.aggregations {
		if strings.Contains(key, timeWindow) {
			filteredAggregations[key] = aggregation
		}
	}

	result, _ := json.Marshal(filteredAggregations)
	return result
}

func CreateFunnel(funnelData []byte) string {
	service := getAnalyticsService()

	var funnel FunnelAnalysis
	if err := json.Unmarshal(funnelData, &funnel); err != nil {
		return ""
	}

	funnelID := uuid.New().String()
	funnel.FunnelID = funnelID

	service.mu.Lock()
	service.funnels[funnelID] = funnel
	service.mu.Unlock()

	return funnelID
}

func GetFunnelResults(funnelId string) []byte {
	service := getAnalyticsService()

	service.mu.RLock()
	funnel, exists := service.funnels[funnelId]
	service.mu.RUnlock()

	if !exists {
		return nil
	}

	result, _ := json.Marshal(funnel)
	return result
}

func HealthCheck() bool {
	service := getAnalyticsService()
	return service.isRunning
}

func GetServiceStats() string {
	service := getAnalyticsService()

	service.mu.RLock()
	stats := service.metrics
	stats.ActiveGoroutines = len(service.eventChannels) + service.processingWorkers + 2 // +2 for aggregation and funnel workers
	service.mu.RUnlock()

	result, _ := json.Marshal(stats)
	return string(result)
}

// Main function (required for Go components)
func main() {
	// Initialize the service
	getAnalyticsService()

	// Keep the service running
	select {}
}
