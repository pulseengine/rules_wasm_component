package main

// generateComprehensiveSchemas returns documentation for ALL major rules in rules_wasm_component
func generateComprehensiveSchemas() map[string]RuleSchema {
	return map[string]RuleSchema{
		// ======================
		// WIT & Interface Rules
		// ======================
		"wit_library": {
			Name:        "wit_library",
			Type:        "rule",
			Description: "Defines a WIT (WebAssembly Interface Types) library. Processes WIT files and makes them available for use in WASM component builds and binding generation.",
			LoadFrom:    "@rules_wasm_component//wit:defs.bzl",
			Attributes: map[string]Attribute{
				"name":         {"string", true, nil, "A unique name for this target", nil},
				"srcs":         {"label_list", true, nil, "WIT source files (*.wit)", nil},
				"package_name": {"string", false, nil, "WIT package name (e.g., 'my:package@1.0.0'). Defaults to target name if not specified.", nil},
				"deps":         {"label_list", false, nil, "WIT library dependencies. Each dependency must provide WitInfo.", nil},
				"world":        {"string", false, nil, "Optional world name to export from this library", nil},
				"interfaces":   {"string_list", false, nil, "List of interface names defined in this library", nil},
			},
			Examples: []Example{
				{"Simple WIT library", "Basic WIT library with a single interface file", `wit_library(
    name = "my_interfaces",
    package_name = "my:pkg@1.0.0",
    srcs = ["interfaces.wit"],
)`},
				{"WIT library with dependencies", "WIT library that imports from another package", `wit_library(
    name = "consumer_interfaces",
    package_name = "consumer:app@1.0.0",
    srcs = ["consumer.wit"],
    deps = ["//external:lib_interfaces"],
)`},
			},
		},
		"wit_bindgen": {
			Name:        "wit_bindgen",
			Type:        "rule",
			Description: "Generates language bindings from WIT files using wit-bindgen tool. Creates bindings for various target languages from WebAssembly Interface Types.",
			LoadFrom:    "@rules_wasm_component//wit:defs.bzl",
			Attributes: map[string]Attribute{
				"name":     {"string", true, nil, "A unique name for this target", nil},
				"wit":      {"label", true, nil, "WIT library to generate bindings for", nil},
				"language": {"string", true, nil, "Target language for binding generation", []string{"rust", "c", "go", "python", "js"}},
				"options":  {"string_list", false, nil, "Additional options for wit-bindgen", nil},
				"world":    {"string", false, nil, "Specific world to generate bindings for", nil},
			},
			Examples: []Example{
				{"Rust bindings", "Generate Rust bindings from WIT", `wit_bindgen(
    name = "rust_bindings",
    wit = ":my_interfaces",
    language = "rust",
)`},
			},
		},
		"wit_deps_check": {
			Name:        "wit_deps_check",
			Type:        "rule",
			Description: "Analyzes a WIT file for missing dependencies and suggests fixes. Helps developers identify and resolve dependency issues.",
			LoadFrom:    "@rules_wasm_component//wit:defs.bzl",
			Attributes: map[string]Attribute{
				"name":     {"string", true, nil, "A unique name for this target", nil},
				"wit_file": {"label", true, nil, "WIT file to analyze for dependencies", nil},
			},
			Examples: []Example{
				{"Dependency analysis", "Check a WIT file for missing dependencies", `wit_deps_check(
    name = "check_deps",
    wit_file = "consumer.wit",
)`},
			},
		},
		"wit_markdown": {
			Name:        "wit_markdown",
			Type:        "rule",
			Description: "Generates markdown documentation from WIT files. Creates human-readable documentation from WebAssembly Interface Types.",
			LoadFrom:    "@rules_wasm_component//wit:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {"string", true, nil, "A unique name for this target", nil},
				"wit":  {"label", true, nil, "WIT library to generate documentation for", nil},
			},
			Examples: []Example{
				{"Generate docs", "Create markdown documentation from WIT", `wit_markdown(
    name = "api_docs",
    wit = ":my_interfaces",
)`},
			},
		},

		// ======================
		// Rust Component Rules
		// ======================
		"rust_wasm_component": {
			Name:        "rust_wasm_component",
			Type:        "rule",
			Description: "Builds a Rust WebAssembly component. Compiles Rust source code into a WASM component using the Rust toolchain.",
			LoadFrom:    "@rules_wasm_component//rust:defs.bzl",
			Attributes: map[string]Attribute{
				"name":           {"string", true, nil, "A unique name for this target", nil},
				"srcs":           {"label_list", true, nil, "Rust source files", nil},
				"deps":           {"label_list", false, nil, "Rust dependencies (crates)", nil},
				"adapter":        {"label", false, nil, "Optional WASI adapter", nil},
				"crate_features": {"string_list", false, nil, "Rust crate features", nil},
				"rustc_flags":    {"string_list", false, nil, "Additional rustc flags", nil},
			},
			Examples: []Example{
				{"Basic Rust component", "Simple Rust WASM component", `rust_wasm_component(
    name = "my_component",
    srcs = ["src/lib.rs"],
    deps = ["@crates//:serde"],
)`},
			},
		},
		"rust_wasm_component_bindgen": {
			Name:        "rust_wasm_component_bindgen",
			Type:        "rule",
			Description: "Builds a Rust WebAssembly component with WIT binding generation. Compiles Rust source code into a WASM component and generates language bindings from WIT interfaces.",
			LoadFrom:    "@rules_wasm_component//rust:defs.bzl",
			Attributes: map[string]Attribute{
				"name":     {"string", true, nil, "A unique name for this target", nil},
				"srcs":     {"label_list", true, nil, "Rust source files", nil},
				"wit":      {"label", true, nil, "WIT library target that provides interfaces for this component", nil},
				"profiles": {"string_list", false, stringPtr("['release']"), "Build profiles to generate", []string{"debug", "release", "custom"}},
				"deps":     {"label_list", false, nil, "Rust dependencies (crates)", nil},
			},
			Examples: []Example{
				{"Basic Rust component", "Simple Rust WASM component with WIT bindings", `rust_wasm_component_bindgen(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":my_interfaces",
)`},
				{"Multi-profile component", "Component built with multiple optimization profiles", `rust_wasm_component_bindgen(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":my_interfaces",
    profiles = ["debug", "release"],
)`},
			},
		},
		"rust_wasm_component_test": {
			Name:        "rust_wasm_component_test",
			Type:        "rule",
			Description: "Tests a Rust WASM component using wasmtime runtime. Provides automated testing for WebAssembly components.",
			LoadFrom:    "@rules_wasm_component//rust:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"component": {"label", true, nil, "WASM component to test", nil},
			},
			Examples: []Example{
				{"Component test", "Test a WASM component", `rust_wasm_component_test(
    name = "my_component_test",
    component = ":my_component",
)`},
			},
		},

		// ======================
		// Go Component Rules
		// ======================
		"go_wasm_component": {
			Name:        "go_wasm_component",
			Type:        "rule",
			Description: "Builds a Go WebAssembly component using TinyGo. Compiles Go source code into a WASM component with WASI Preview 2 support.",
			LoadFrom:    "@rules_wasm_component//go:defs.bzl",
			Attributes: map[string]Attribute{
				"name":         {"string", true, nil, "A unique name for this target", nil},
				"srcs":         {"label_list", true, nil, "Go source files", nil},
				"go_mod":       {"label", false, nil, "go.mod file for dependency management", nil},
				"adapter":      {"label", false, nil, "Optional WASI adapter", nil},
				"optimization": {"string", false, stringPtr("'release'"), "Build optimization level", []string{"debug", "release"}},
				"world":        {"string", false, nil, "WIT world for the component", nil},
			},
			Examples: []Example{
				{"Basic Go component", "Simple Go WASM component with TinyGo", `go_wasm_component(
    name = "calculator_component",
    srcs = ["calculator.go", "main.go"],
    go_mod = "go.mod",
    optimization = "release",
)`},
			},
		},
		"go_wit_bindgen": {
			Name:        "go_wit_bindgen",
			Type:        "rule",
			Description: "Generates Go bindings from WIT files using wit-bindgen-go. Creates Go language bindings for WebAssembly Interface Types.",
			LoadFrom:    "@rules_wasm_component//go:defs.bzl",
			Attributes: map[string]Attribute{
				"name":  {"string", true, nil, "A unique name for this target", nil},
				"world": {"string", true, nil, "WIT world to generate bindings for", nil},
			},
			Examples: []Example{
				{"Go bindings", "Generate Go bindings from WIT", `go_wit_bindgen(
    name = "calculator_bindings",
    world = "calculator-world",
)`},
			},
		},

		// ======================
		// JavaScript Component Rules
		// ======================
		"js_component": {
			Name:        "js_component",
			Type:        "rule",
			Description: "Builds a JavaScript WebAssembly component using ComponentizeJS. Transpiles JavaScript/TypeScript source code into a WASM component.",
			LoadFrom:    "@rules_wasm_component//js:defs.bzl",
			Attributes: map[string]Attribute{
				"name":    {"string", true, nil, "A unique name for this target", nil},
				"srcs":    {"label_list", true, nil, "JavaScript/TypeScript source files", nil},
				"wit":     {"label", true, nil, "WIT library for the component interfaces", nil},
				"entry":   {"string", false, nil, "Entry point for the component", nil},
				"package": {"label", false, nil, "package.json file", nil},
			},
			Examples: []Example{
				{"JS component", "JavaScript WebAssembly component", `js_component(
    name = "calculator_js",
    srcs = ["src/calculator.js"],
    wit = ":calculator_wit",
)`},
			},
		},
		"jco_transpile": {
			Name:        "jco_transpile",
			Type:        "rule",
			Description: "Transpiles WebAssembly components to JavaScript using jco (JavaScript Component Tools). Converts WASM components into JavaScript modules.",
			LoadFrom:    "@rules_wasm_component//js:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"component": {"label", true, nil, "WebAssembly component to transpile", nil},
				"options":   {"string_list", false, nil, "Additional jco options", nil},
			},
			Examples: []Example{
				{"Transpile component", "Convert WASM component to JavaScript", `jco_transpile(
    name = "calculator_js_bindings",
    component = ":calculator_component",
)`},
			},
		},

		// ======================
		// C++ Component Rules
		// ======================
		"cpp_component": {
			Name:        "cpp_component",
			Type:        "rule",
			Description: "Builds a C++ WebAssembly component using WASI SDK. Compiles C++ source code into a WASM component with Preview2 support.",
			LoadFrom:    "@rules_wasm_component//cpp:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {"string", true, nil, "A unique name for this target", nil},
				"srcs": {"label_list", true, nil, "C++ source files", nil},
				"hdrs": {"label_list", false, nil, "C++ header files", nil},
				"deps": {"label_list", false, nil, "C++ dependencies", nil},
				"wit":  {"label", false, nil, "WIT library for component interfaces", nil},
			},
			Examples: []Example{
				{"C++ component", "C++ WebAssembly component", `cpp_component(
    name = "calculator_cpp",
    srcs = ["calculator.cpp"],
    hdrs = ["calculator.h"],
)`},
			},
		},

		// ======================
		// WAC Composition Rules
		// ======================
		"wac_compose": {
			Name:        "wac_compose",
			Type:        "rule",
			Description: "Composes multiple WebAssembly components into a single application using WAC (WebAssembly Composition) format.",
			LoadFrom:    "@rules_wasm_component//wac:defs.bzl",
			Attributes: map[string]Attribute{
				"name":             {"string", true, nil, "A unique name for this target", nil},
				"components":       {"string_dict", true, nil, "Map of component targets to component names in composition", nil},
				"composition":      {"string", false, nil, "Inline WAC composition script", nil},
				"composition_file": {"label", false, nil, "WAC composition file (alternative to inline composition)", nil},
				"profile":          {"string", false, stringPtr("'release'"), "Build profile for components", nil},
			},
			Examples: []Example{
				{"Simple composition", "Compose two components with inline WAC script", `wac_compose(
    name = "my_app",
    components = {
        ":component_a": "comp_a",
        ":component_b": "comp_b",
    },
    composition = '''
        let a = new comp_a {};
        let b = new comp_b {};
        export a;
    ''',
)`},
			},
		},
		"wac_remote_compose": {
			Name:        "wac_remote_compose",
			Type:        "rule",
			Description: "Composes WebAssembly components including remote components from OCI registries. Enables distributed component architecture.",
			LoadFrom:    "@rules_wasm_component//wac:defs.bzl",
			Attributes: map[string]Attribute{
				"name":              {"string", true, nil, "A unique name for this target", nil},
				"local_components":  {"string_dict", false, nil, "Local component targets", nil},
				"remote_components": {"string_dict", false, nil, "Remote OCI component references", nil},
				"composition_file":  {"label", false, nil, "WAC composition file", nil},
				"registry_config":   {"label", false, nil, "Registry configuration for OCI access", nil},
			},
			Examples: []Example{
				{"Remote composition", "Compose local and remote components", `wac_remote_compose(
    name = "distributed_app",
    local_components = {
        ":frontend": "frontend",
    },
    remote_components = {
        "ghcr.io/org/backend:v1.0.0": "backend",
    },
    composition_file = "app.wac",
)`},
			},
		},

		// ======================
		// WASM Component Tools
		// ======================
		"wasm_component_new": {
			Name:        "wasm_component_new",
			Type:        "rule",
			Description: "Creates a WebAssembly component from a core WASM module using wasm-tools component new. Wraps core modules into the component model.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name":    {"string", true, nil, "A unique name for this target", nil},
				"module":  {"label", true, nil, "Core WASM module to wrap", nil},
				"adapter": {"label", false, nil, "WASI adapter to use", nil},
			},
			Examples: []Example{
				{"Wrap module", "Convert core WASM module to component", `wasm_component_new(
    name = "my_component",
    module = ":my_module",
    adapter = "//wasm/adapters:wasi_snapshot_preview1",
)`},
			},
		},
		"wasm_validate": {
			Name:        "wasm_validate",
			Type:        "rule",
			Description: "Validates WebAssembly components and modules using wasm-tools validate. Ensures WASM files are well-formed.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {"string", true, nil, "A unique name for this target", nil},
				"wasm": {"label", true, nil, "WASM file to validate", nil},
			},
			Examples: []Example{
				{"Validate component", "Validate a WASM component", `wasm_validate(
    name = "validate_component",
    wasm = ":my_component",
)`},
			},
		},
		"wasm_signing": {
			Name:        "wasm_signing",
			Type:        "rule",
			Description: "Signs WebAssembly components using wasmsign2 for secure deployment. Provides cryptographic signatures for component integrity.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"component": {"label", true, nil, "Component to sign", nil},
				"keys":      {"label", true, nil, "Signing keys", nil},
				"detached":  {"bool", false, nil, "Create detached signature", nil},
			},
			Examples: []Example{
				{"Sign component", "Sign a WebAssembly component", `wasm_signing(
    name = "signed_component",
    component = ":my_component",
    keys = ":signing_keys",
)`},
			},
		},
		"wasm_keygen": {
			Name:        "wasm_keygen",
			Type:        "rule",
			Description: "Generates cryptographic keys for WebAssembly component signing using wasmsign2. Creates key pairs for secure component distribution.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name":           {"string", true, nil, "A unique name for this target", nil},
				"openssh_format": {"bool", false, nil, "Generate keys in OpenSSH format", nil},
			},
			Examples: []Example{
				{"Generate keys", "Create signing keys", `wasm_keygen(
    name = "production_keys",
    openssh_format = True,
)`},
			},
		},

		// ======================
		// WKG Registry Rules
		// ======================
		"wkg_registry_config": {
			Name:        "wkg_registry_config",
			Type:        "rule",
			Description: "Configures WebAssembly component registries for OCI distribution. Sets up authentication and registry endpoints for component publishing and retrieval.",
			LoadFrom:    "@rules_wasm_component//wkg:defs.bzl",
			Attributes: map[string]Attribute{
				"name":                   {"string", true, nil, "A unique name for this target", nil},
				"registries":             {"string_list", true, nil, "List of registry configurations", nil},
				"default_registry":       {"string", false, nil, "Default registry to use", nil},
				"cache_dir":              {"string", false, nil, "Directory for caching components", nil},
				"enable_mirror_fallback": {"bool", false, nil, "Enable fallback to mirror registries", nil},
			},
			Examples: []Example{
				{"Registry setup", "Configure multiple component registries", `wkg_registry_config(
    name = "production_registries",
    registries = [
        "github|ghcr.io|oci|env|GITHUB_TOKEN",
        "docker|docker.io|oci|env|DOCKER_TOKEN",
    ],
    default_registry = "github",
)`},
			},
		},
		"wasm_component_from_oci": {
			Name:        "wasm_component_from_oci",
			Type:        "rule",
			Description: "Downloads WebAssembly components from OCI registries. Enables using remote components from container registries in builds.",
			LoadFrom:    "@rules_wasm_component//wkg:defs.bzl",
			Attributes: map[string]Attribute{
				"name":            {"string", true, nil, "A unique name for this target", nil},
				"registry":        {"string", true, nil, "Registry hostname", nil},
				"namespace":       {"string", true, nil, "Registry namespace", nil},
				"component_name":  {"string", true, nil, "Component name", nil},
				"tag":             {"string", false, stringPtr("'latest'"), "Component tag or version", nil},
				"registry_config": {"label", false, nil, "Registry configuration", nil},
			},
			Examples: []Example{
				{"Download component", "Pull component from OCI registry", `wasm_component_from_oci(
    name = "auth_service",
    registry = "ghcr.io",
    namespace = "my-org",
    component_name = "auth-service",
    tag = "v1.0.0",
)`},
			},
		},

		// ======================
		// Providers
		// ======================
		"WitInfo": {
			Name:        "WitInfo",
			Type:        "provider",
			Description: "Provider that contains information about WIT interfaces and their dependencies.",
			Fields: map[string]ProviderField{
				"wit_files":       {"depset", "Depset of WIT source files for this library"},
				"wit_deps":        {"depset", "Depset of transitive WIT dependencies"},
				"package_name":    {"string", "WIT package name (e.g., 'my:package@1.0.0')"},
				"world_name":      {"string", "World name exported by this library (optional)"},
				"interface_names": {"string_list", "List of interface names defined in this library"},
			},
			Examples: []Example{
				{"Using WitInfo in custom rules", "Access WIT metadata in rule implementations", `def _my_rule_impl(ctx):
    wit_info = ctx.attr.wit[WitInfo]
    package_name = wit_info.package_name
    wit_files = wit_info.wit_files.to_list()
    # Use wit_info...`},
			},
		},
		"WasmComponentInfo": {
			Name:        "WasmComponentInfo",
			Type:        "provider",
			Description: "Provider that contains information about a compiled WebAssembly component.",
			Fields: map[string]ProviderField{
				"wasm_file":      {"File", "The compiled WASM component file"},
				"wit_info":       {"WitInfo", "WitInfo provider from the component's interfaces"},
				"component_type": {"string", "Type of component (module or component)"},
				"imports":        {"string_list", "List of imported interfaces"},
				"exports":        {"string_list", "List of exported interfaces"},
				"metadata":       {"dict", "Component metadata dictionary"},
			},
			Examples: []Example{
				{"Using WasmComponentInfo", "Access component metadata", `def _my_rule_impl(ctx):
    component_info = ctx.attr.component[WasmComponentInfo]
    wasm_file = component_info.wasm_file
    exports = component_info.exports
    # Use component_info...`},
			},
		},
		"WacCompositionInfo": {
			Name:        "WacCompositionInfo",
			Type:        "provider",
			Description: "Provider that contains information about a WAC composition of multiple components.",
			Fields: map[string]ProviderField{
				"composed_wasm":   {"File", "The composed WASM file"},
				"components":      {"dict", "Dictionary of component name to WasmComponentInfo"},
				"composition_wit": {"File", "WIT file describing the composition"},
				"instantiations":  {"string_list", "List of component instantiations"},
				"connections":     {"string_list", "List of inter-component connections"},
			},
			Examples: []Example{
				{"Using WacCompositionInfo", "Access composition metadata", `def _my_rule_impl(ctx):
    composition_info = ctx.attr.composition[WacCompositionInfo]
    composed_wasm = composition_info.composed_wasm
    components = composition_info.components
    # Use composition_info...`},
			},
		},
	}
}
