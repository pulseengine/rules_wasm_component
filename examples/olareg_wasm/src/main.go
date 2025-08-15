package main

// Simple demonstration of olareg concept as WASM component
// This is a basic proof-of-concept showing the structure

var (
	registryRunning bool = false
	registryAddr    string
	registryDataDir string
)

//go:export start-server
func startServer(addr, dataDir string, readOnly, enablePush, enableDelete bool) (int32, string) {
	if registryRunning {
		return 0, "Registry is already running"
	}

	registryAddr = addr
	registryDataDir = dataDir
	registryRunning = true

	// In a real implementation, this would:
	// 1. Create HTTP server with OCI Distribution API endpoints
	// 2. Set up filesystem storage in dataDir
	// 3. Handle authentication and authorization
	// 4. Implement blob and manifest storage

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

func main() {
	// Component entry point - TinyGo will handle the WASM exports
}
