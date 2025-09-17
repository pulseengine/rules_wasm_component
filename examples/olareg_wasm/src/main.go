package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"
)

// Enhanced olareg implementation with in-memory storage for testing
// CLI WASI version - uses command line arguments and standard I/O

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

func stopServer() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	registryRunning = false
	registryAddr = ""
	registryDataDir = ""

	return 1, "Registry stopped successfully"
}

func getStatus() string {
	if !registryRunning {
		return "stopped"
	}
	return "running on " + registryAddr
}

func healthCheck() bool {
	return registryRunning
}

// Component operations exports

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

func componentExists(name, tag string) bool {
	if !registryRunning {
		return false
	}

	key := componentKey(name, tag)
	_, exists := components[key]
	return exists
}

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

func blobExists(digest string) bool {
	if !registryRunning {
		return false
	}

	_, exists := blobs[digest]
	return exists
}

// Test lifecycle management exports

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

func getMetrics() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	metrics := fmt.Sprintf("uploads:%d,downloads:%d,deletes:%d,components:%d,blobs:%d",
		uploadCount, downloadCount, deleteCount, len(components), len(blobs))

	return 1, metrics
}

func getComponentCount() uint32 {
	if !registryRunning {
		return 0
	}
	return uint32(len(components))
}

func getBlobCount() uint32 {
	if !registryRunning {
		return 0
	}
	return uint32(len(blobs))
}

// Error simulation exports

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

func clearSimulations() (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	errorSimulations = nil
	latencySimulations = nil

	return 1, "All simulations cleared"
}

// Authentication and security exports

func setAuthMode(mode string) (int32, string) {
	if !registryRunning {
		return 0, "Registry is not running"
	}

	authMode = mode
	return 1, "Auth mode set to " + mode
}

func validateSignature(componentData, signature []byte) bool {
	if !registryRunning {
		return false
	}

	// Basic signature validation - in real implementation would use crypto
	return len(signature) > 0 && len(componentData) > 0
}

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
	// Parse command line arguments
	addr := ":5001"
	if len(os.Args) > 1 {
		addr = os.Args[1]
	}

	// Initialize registry
	initRegistry()

	// Setup HTTP routes
	setupRoutes()

	fmt.Printf("🚀 Olareg WASM Registry starting on %s\n", addr)
	fmt.Println("📦 In-memory OCI registry for testing and development")
	fmt.Println("🔗 Ready to accept OCI registry API calls")

	// Start HTTP server
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("❌ Server failed to start: %v\n", err)
		os.Exit(1)
	}
}

func initRegistry() {
	// Initialize storage
	components = make(map[string]*Component)
	blobs = make(map[string]*Blob)

	// Set registry as running
	registryRunning = true
	registryAddr = ":5001"
	registryDataDir = "/tmp"
	readOnly = false
	enablePush = true
	enableDelete = true

	fmt.Println("✅ Registry initialized with in-memory storage")
}

func setupRoutes() {
	// OCI Registry API routes
	http.HandleFunc("/v2/", handleV2Root)
	http.HandleFunc("/v2/_catalog", handleCatalog)

	// Health and status endpoints
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/metrics", handleMetrics)

	// Test/debug endpoints
	http.HandleFunc("/debug/components", handleDebugComponents)
	http.HandleFunc("/debug/reset", handleDebugReset)
}

func printUsage() {
	fmt.Println("Olareg WASM - In-memory OCI registry")
	fmt.Println("Usage: olareg <command> [args...]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  start-server <addr> <dataDir> <readOnly> <enablePush> <enableDelete>")
	fmt.Println("  stop-server")
	fmt.Println("  get-status")
	fmt.Println("  health-check")
	fmt.Println("  upload-component <name> <tag> <data>")
	fmt.Println("  download-component <name> <tag>")
	fmt.Println("  list-components")
	fmt.Println("  component-exists <name> <tag>")
	fmt.Println("  create-test-data <component1:tag1,component2:tag2,...>")
	fmt.Println("  reset-registry")
	fmt.Println("  get-metrics")
}

// CLI wrapper functions that call the original implementations
func startServerCLI(addr, dataDir string, readOnlyFlag, enablePushFlag, enableDeleteFlag bool) (int32, string) {
	return startServer(addr, dataDir, readOnlyFlag, enablePushFlag, enableDeleteFlag)
}

func stopServerCLI() (int32, string) {
	return stopServer()
}

func getStatusCLI() string {
	return getStatus()
}

func healthCheckCLI() bool {
	return healthCheck()
}

func uploadComponentCLI(name, tag string, componentData []byte) (int32, string) {
	return uploadComponent(name, tag, componentData)
}

func downloadComponentCLI(name, tag string) (int32, string, []byte) {
	return downloadComponent(name, tag)
}

func listComponentsCLI() (int32, string, []string) {
	return listComponents()
}

func componentExistsCLI(name, tag string) bool {
	return componentExists(name, tag)
}

func createTestDataCLI(componentSpecs []string) (int32, string) {
	return createTestData(componentSpecs)
}

func resetRegistryCLI() (int32, string) {
	return resetRegistry()
}

func getMetricsCLI() (int32, string) {
	return getMetrics()
}

// HTTP Handler Functions

func handleV2Root(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/v2/" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message": "Olareg WASM Registry"}`))
		return
	}
	http.NotFound(w, r)
}

func handleCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	_, _, componentList := listComponents()

	catalog := struct {
		Repositories []string `json:"repositories"`
	}{
		Repositories: componentList,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(catalog)
}

func handleManifest(w http.ResponseWriter, r *http.Request) {
	// Parse URL path to extract name and reference (tag/digest)
	// Format: /v2/<name>/manifests/<reference>

	// This is a simplified implementation
	// Full OCI registry would handle complex manifest operations
	w.Header().Set("Content-Type", "application/vnd.docker.distribution.manifest.v2+json")
	w.Write([]byte(`{"mediaType": "application/vnd.docker.distribution.manifest.v2+json"}`))
}

func handleBlob(w http.ResponseWriter, r *http.Request) {
	// Parse URL path to extract name and digest
	// Format: /v2/<name>/blobs/<digest>

	// This is a simplified implementation
	// Full OCI registry would handle blob upload/download
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Write([]byte("mock blob data"))
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	healthy := healthCheck()
	status := "unhealthy"
	statusCode := http.StatusServiceUnavailable

	if healthy {
		status = "healthy"
		statusCode = http.StatusOK
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	response := struct {
		Status string `json:"status"`
		Addr   string `json:"addr"`
	}{
		Status: status,
		Addr:   registryAddr,
	}

	json.NewEncoder(w).Encode(response)
}

func handleMetrics(w http.ResponseWriter, r *http.Request) {
	_, metricsData := getMetrics()

	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(metricsData))
}

func handleDebugComponents(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		_, _, componentList := listComponents()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"components": componentList,
			"count":      len(componentList),
		})

	case "POST":
		// Create test data
		specs := []string{"test:v1", "mock:v2", "demo:latest"}
		result, msg := createTestData(specs)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"result":  result,
			"message": msg,
		})
	}
}

func handleDebugReset(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	result, msg := resetRegistry()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"result":  result,
		"message": msg,
	})
}
