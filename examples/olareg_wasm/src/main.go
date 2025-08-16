package main

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"time"
)

// Enhanced olareg implementation with in-memory storage for testing

// Component represents a stored WASM component
type Component struct {
	Name      string
	Tag       string
	Data      []byte
	Manifest  []byte
	Signature []byte
	Timestamp time.Time
}

// Blob represents stored blob data
type Blob struct {
	Digest string
	Data   []byte
}

// ErrorSimulation represents error simulation configuration
type ErrorSimulation struct {
	Operation string
	ErrorType string
	Enabled   bool
}

// LatencySimulation represents latency simulation configuration
type LatencySimulation struct {
	Operation string
	LatencyMs uint32
	Enabled   bool
}

var (
	// Basic registry state
	registryRunning bool = false
	registryAddr    string
	registryDataDir string
	readOnly        bool
	enablePush      bool
	enableDelete    bool

	// In-memory storage
	components map[string]*Component = make(map[string]*Component)
	blobs      map[string]*Blob      = make(map[string]*Blob)

	// Test configuration
	authMode           string = "none"
	errorSimulations   []ErrorSimulation
	latencySimulations []LatencySimulation

	// Metrics
	uploadCount   uint32
	downloadCount uint32
	deleteCount   uint32
)

// Helper functions
func componentKey(name, tag string) string {
	return name + ":" + tag
}

func calculateDigest(data []byte) string {
	hash := sha256.Sum256(data)
	return fmt.Sprintf("sha256:%x", hash)
}

func checkErrorSimulation(operation string) (bool, string) {
	for _, sim := range errorSimulations {
		if sim.Enabled && sim.Operation == operation {
			return true, sim.ErrorType
		}
	}
	return false, ""
}

func applyLatencySimulation(operation string) {
	for _, sim := range latencySimulations {
		if sim.Enabled && sim.Operation == operation {
			// In a real implementation, this would add actual delay
			// For testing, we just track that latency would be applied
			break
		}
	}
}

// Basic server lifecycle exports

//go:export start-server
func startServer(addr, dataDir string, readOnlyFlag, enablePushFlag, enableDeleteFlag bool) (int32, string) {
	if registryRunning {
		return 0, "Registry is already running"
	}

	registryAddr = addr
	registryDataDir = dataDir
	registryRunning = true
	readOnly = readOnlyFlag
	enablePush = enablePushFlag
	enableDelete = enableDeleteFlag

	// Initialize storage
	components = make(map[string]*Component)
	blobs = make(map[string]*Blob)

	return 1, "Registry started on " + addr + ", data dir: " + dataDir
}

//go:export stop-server
func stopServer() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	registryRunning = false
	registryAddr = ""
	registryDataDir = ""

	return 1, "Registry stopped successfully"
}

//go:export get-status
func getStatus() string {
	if !registryRunning {
		return "stopped"
	}
	return "running on " + registryAddr
}

//go:export health-check
func healthCheck() bool {
	return registryRunning
}

// Component operations exports

//go:export upload-component
func uploadComponent(name, tag string, componentData []byte) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	if readOnly || !enablePush {
		return 0, "Registry is read-only or push disabled"
	}

	if hasError, errorType := checkErrorSimulation("upload"); hasError {
		return 0, "Simulated error: " + errorType
	}

	applyLatencySimulation("upload")

	key := componentKey(name, tag)
	components[key] = &Component{
		Name:      name,
		Tag:       tag,
		Data:      componentData,
		Timestamp: time.Now(),
	}

	uploadCount++
	return 1, "Component uploaded successfully"
}

//go:export download-component
func downloadComponent(name, tag string) (int32, string, []byte) {
	if !registryRunning {
		return 0, "Registry is not running", nil
	}

	if hasError, errorType := checkErrorSimulation("download"); hasError {
		return 0, "Simulated error: " + errorType, nil
	}

	applyLatencySimulation("download")

	key := componentKey(name, tag)
	component, exists := components[key]
	if !exists {
		return 0, "Component not found", nil
	}

	downloadCount++
	return 1, "Component downloaded successfully", component.Data
}

//go:export list-components
func listComponents() (int32, string, []string) {
	if !registryRunning {
		return 0, "Registry is not running", nil
	}

	var componentList []string
	for key := range components {
		componentList = append(componentList, key)
	}

	return 1, "Components listed successfully", componentList
}

//go:export component-exists
func componentExists(name, tag string) bool {
	if !registryRunning {
		return false
	}

	key := componentKey(name, tag)
	_, exists := components[key]
	return exists
}

//go:export delete-component
func deleteComponent(name, tag string) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	if readOnly || !enableDelete {
		return 0, "Registry is read-only or delete disabled"
	}

	key := componentKey(name, tag)
	if _, exists := components[key]; !exists {
		return 0, "Component not found"
	}

	delete(components, key)
	deleteCount++
	return 1, "Component deleted successfully"
}

// Manifest and blob operations exports

//go:export upload-manifest
func uploadManifest(name, tag string, manifestData []byte) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	if readOnly || !enablePush {
		return 0, "Registry is read-only or push disabled"
	}

	key := componentKey(name, tag)
	if component, exists := components[key]; exists {
		component.Manifest = manifestData
		return 1, "Manifest uploaded successfully"
	}

	// Create component with manifest only
	components[key] = &Component{
		Name:      name,
		Tag:       tag,
		Manifest:  manifestData,
		Timestamp: time.Now(),
	}

	return 1, "Manifest uploaded successfully"
}

//go:export download-manifest
func downloadManifest(name, tag string) (int32, string, []byte) {
	if !registryRunning {
		return 0, "Registry is not running", nil
	}

	key := componentKey(name, tag)
	component, exists := components[key]
	if !exists {
		return 0, "Component not found", nil
	}

	if len(component.Manifest) == 0 {
		return 0, "No manifest available", nil
	}

	return 1, "Manifest downloaded successfully", component.Manifest
}

//go:export upload-blob
func uploadBlob(digest string, blobData []byte) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	if readOnly || !enablePush {
		return 0, "Registry is read-only or push disabled"
	}

	// Verify digest
	calculatedDigest := calculateDigest(blobData)
	if digest != calculatedDigest {
		return 0, "Digest mismatch"
	}

	blobs[digest] = &Blob{
		Digest: digest,
		Data:   blobData,
	}

	return 1, "Blob uploaded successfully"
}

//go:export download-blob
func downloadBlob(digest string) (int32, string, []byte) {
	if !registryRunning {
		return 0, "Registry is not running", nil
	}

	blob, exists := blobs[digest]
	if !exists {
		return 0, "Blob not found", nil
	}

	return 1, "Blob downloaded successfully", blob.Data
}

//go:export blob-exists
func blobExists(digest string) bool {
	if !registryRunning {
		return false
	}

	_, exists := blobs[digest]
	return exists
}

// Test lifecycle management exports

//go:export create-test-data
func createTestData(componentSpecs []string) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	for _, spec := range componentSpecs {
		parts := strings.Split(spec, ":")
		if len(parts) != 2 {
			continue
		}

		name, tag := parts[0], parts[1]
		testData := []byte("test-component-data-for-" + spec)
		key := componentKey(name, tag)

		components[key] = &Component{
			Name:      name,
			Tag:       tag,
			Data:      testData,
			Manifest:  []byte(`{"test": "manifest"}`),
			Timestamp: time.Now(),
		}
	}

	return 1, fmt.Sprintf("Created %d test components", len(componentSpecs))
}

//go:export reset-registry
func resetRegistry() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	components = make(map[string]*Component)
	blobs = make(map[string]*Blob)
	uploadCount = 0
	downloadCount = 0
	deleteCount = 0

	// Clear simulations
	errorSimulations = nil
	latencySimulations = nil

	return 1, "Registry reset successfully"
}

//go:export get-metrics
func getMetrics() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	metrics := fmt.Sprintf("uploads:%d,downloads:%d,deletes:%d,components:%d,blobs:%d",
		uploadCount, downloadCount, deleteCount, len(components), len(blobs))

	return 1, metrics
}

//go:export get-component-count
func getComponentCount() uint32 {
	if !registryRunning {
		return 0
	}
	return uint32(len(components))
}

//go:export get-blob-count
func getBlobCount() uint32 {
	if !registryRunning {
		return 0
	}
	return uint32(len(blobs))
}

// Error simulation exports

//go:export simulate-failure
func simulateFailure(operation, errorType string) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	errorSimulations = append(errorSimulations, ErrorSimulation{
		Operation: operation,
		ErrorType: errorType,
		Enabled:   true,
	})

	return 1, "Error simulation configured for " + operation
}

//go:export set-latency
func setLatency(operation string, latencyMs uint32) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	latencySimulations = append(latencySimulations, LatencySimulation{
		Operation: operation,
		LatencyMs: latencyMs,
		Enabled:   true,
	})

	return 1, "Latency simulation configured for " + operation
}

//go:export clear-simulations
func clearSimulations() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	errorSimulations = nil
	latencySimulations = nil

	return 1, "All simulations cleared"
}

// Authentication and security exports

//go:export set-auth-mode
func setAuthMode(mode string) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	authMode = mode
	return 1, "Auth mode set to " + mode
}

//go:export validate-signature
func validateSignature(componentData, signature []byte) bool {
	if !registryRunning {
		return false
	}

	// Basic signature validation - in real implementation would use crypto
	return len(signature) > 0 && len(componentData) > 0
}

//go:export get-component-signature
func getComponentSignature(name, tag string) (int32, string, []byte) {
	if !registryRunning {
		return 0, "Registry is not running", nil
	}

	key := componentKey(name, tag)
	component, exists := components[key]
	if !exists {
		return 0, "Component not found", nil
	}

	if len(component.Signature) == 0 {
		return 0, "No signature available", nil
	}

	return 1, "Signature retrieved successfully", component.Signature
}

func main() {
	// Component entry point - TinyGo will handle the WASM exports
}
