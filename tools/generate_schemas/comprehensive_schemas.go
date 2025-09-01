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
		"rust_wasm_component_wizer": {
			Name:        "rust_wasm_component_wizer",
			Type:        "macro",
			Description: "Builds a Rust WebAssembly component with Wizer pre-initialization. Provides 1.35-6x startup performance improvements by running initialization code at build time.",
			LoadFrom:    "@rules_wasm_component//rust:defs.bzl",
			Attributes: map[string]Attribute{
				"name":               {"string", true, nil, "A unique name for this target", nil},
				"srcs":               {"label_list", true, nil, "Rust source files", nil},
				"deps":               {"label_list", false, nil, "Rust dependencies", nil},
				"wit":                {"label", false, nil, "WIT library for binding generation", nil},
				"adapter":            {"label", false, nil, "Optional WASI adapter", nil},
				"crate_features":     {"string_list", false, nil, "Cargo features to enable", nil},
				"rustc_flags":        {"string_list", false, nil, "Additional rustc flags", nil},
				"profiles":           {"string_list", false, nil, "Build profiles (debug, release)", []string{"debug", "release"}},
				"init_function_name": {"string", false, stringPtr("'wizer.initialize'"), "Name of the Wizer initialization function", nil},
				"crate_root":         {"label", false, nil, "Crate root file (defaults to src/lib.rs)", nil},
				"edition":            {"string", false, stringPtr("'2021'"), "Rust edition", []string{"2015", "2018", "2021"}},
			},
			Examples: []Example{
				{"Wizer component", "Rust component with pre-initialization", `rust_wasm_component_wizer(
    name = "optimized_component",
    srcs = ["src/lib.rs"],
    wit = "//interfaces:calculator",
    init_function_name = "wizer.initialize",
    profiles = ["release"],
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
		"go_wasm_component_test": {
			Name:        "go_wasm_component_test",
			Type:        "rule",
			Description: "Tests a Go WebAssembly component built with TinyGo. Performs comprehensive validation including component format verification, TinyGo-specific pattern checks, and WASI Preview 2 compatibility testing.",
			LoadFrom:    "@rules_wasm_component//go:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"component": {"label", true, nil, "Go WASM component to test", nil},
			},
			Examples: []Example{
				{"Component testing", "Test a TinyGo WebAssembly component", `go_wasm_component_test(
    name = "calculator_component_test",
    component = ":calculator_component",
)`},
			},
		},
		"go_wit_bindgen": {
			Name:        "go_wit_bindgen",
			Type:        "rule",
			Description: "Legacy compatibility function for Go WIT binding generation. **DEPRECATED**: WIT binding generation is now handled automatically by go_wasm_component rule. This function exists for backward compatibility with existing examples and creates a placeholder genrule. For new code, use go_wasm_component directly with wit and world attributes.",
			LoadFrom:    "@rules_wasm_component//go:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {"string", true, nil, "A unique name for this target", nil},
			},
			Examples: []Example{
				{"Legacy compatibility", "Placeholder for backward compatibility (use go_wasm_component instead)", `// DEPRECATED: Use go_wasm_component instead
go_wit_bindgen(
    name = "calculator_bindings",
)

// RECOMMENDED: Use go_wasm_component directly
go_wasm_component(
    name = "calculator_component",
    srcs = ["calculator.go"],
    wit = ":calculator_wit",
    world = "calculator",
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
				"name":         {"string", true, nil, "A unique name for this target", nil},
				"srcs":         {"label_list", true, nil, "JavaScript/TypeScript source files", nil},
				"wit":          {"label", true, nil, "WIT library for the component interfaces", nil},
				"entry_point":  {"string", false, stringPtr("index.js"), "Main entry point file", nil},
				"package_json": {"label", false, nil, "package.json file (auto-generated if not provided)", nil},
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
		"npm_install": {
			Name:        "npm_install",
			Type:        "rule",
			Description: "Installs NPM dependencies for JavaScript components. Runs npm install to fetch dependencies specified in package.json, making them available for JavaScript component builds.",
			LoadFrom:    "@rules_wasm_component//js:defs.bzl",
			Attributes: map[string]Attribute{
				"name":         {"string", true, nil, "A unique name for this target", nil},
				"package_json": {"label", true, nil, "package.json file with dependencies", nil},
			},
			Examples: []Example{
				{"Install NPM deps", "Install NPM dependencies", `npm_install(
    name = "npm_deps",
    package_json = "package.json",
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
		"cpp_wit_bindgen": {
			Name:        "cpp_wit_bindgen",
			Type:        "rule",
			Description: "Generates C/C++ bindings from WIT interface definitions. Creates header and source files for WebAssembly component development.",
			LoadFrom:    "@rules_wasm_component//cpp:defs.bzl",
			Attributes: map[string]Attribute{
				"name":            {"string", true, nil, "A unique name for this target", nil},
				"wit":             {"label", true, nil, "WIT interface definition file", nil},
				"world":           {"string", false, nil, "WIT world to generate bindings for", nil},
				"stubs_only":      {"bool", false, nil, "Generate only stub functions without implementation", nil},
				"string_encoding": {"string", false, nil, "String encoding to use in generated bindings", []string{"utf8", "utf16", "compact-utf16"}},
			},
			Examples: []Example{
				{"C++ bindings", "Generate C++ bindings from WIT", `cpp_wit_bindgen(
    name = "calculator_bindings",
    wit = "calculator.wit",
    world = "calculator",
    string_encoding = "utf8",
)`},
			},
		},
		"cc_component_library": {
			Name:        "cc_component_library",
			Type:        "rule",
			Description: "Creates a static library for use in WebAssembly components. Compiles C/C++ source files into a static library that can be linked into WebAssembly components.",
			LoadFrom:    "@rules_wasm_component//cpp:defs.bzl",
			Attributes: map[string]Attribute{
				"name":              {"string", true, nil, "A unique name for this target", nil},
				"srcs":              {"label_list", true, nil, "C/C++ source files", nil},
				"hdrs":              {"label_list", false, nil, "C/C++ header files", nil},
				"deps":              {"label_list", false, nil, "Dependencies (other cc_component_library targets)", nil},
				"language":          {"string", false, stringPtr("'cpp'"), "Language variant (c or cpp)", []string{"c", "cpp"}},
				"includes":          {"string_list", false, nil, "Additional include directories", nil},
				"defines":           {"string_list", false, nil, "Preprocessor definitions", nil},
				"copts":             {"string_list", false, nil, "Additional compiler options", nil},
				"optimize":          {"bool", false, stringPtr("True"), "Enable optimizations", nil},
				"cxx_std":           {"string", false, nil, "C++ standard (e.g., c++17, c++20, c++23)", nil},
				"enable_exceptions": {"bool", false, nil, "Enable C++ exceptions (increases binary size)", nil},
			},
			Examples: []Example{
				{"C++ library", "Create a static library for components", `cc_component_library(
    name = "math_utils",
    srcs = ["math.cpp", "algorithms.cpp"],
    hdrs = ["math.h", "algorithms.h"],
    language = "cpp",
    cxx_std = "c++20",
    optimize = True,
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
		"wac_bundle": {
			Name:        "wac_bundle",
			Type:        "rule",
			Description: "Bundle WASM components without composition, suitable for WASI components. Collects multiple components into a single bundle directory without creating a composed component.",
			LoadFrom:    "@rules_wasm_component//wac:defs.bzl",
			Attributes: map[string]Attribute{
				"name":       {"string", true, nil, "A unique name for this target", nil},
				"components": {"label_keyed_string_dict", true, nil, "Map of component targets to their names in the bundle", nil},
			},
			Examples: []Example{
				{"Component bundle", "Bundle multiple WASI components", `wac_bundle(
    name = "service_bundle",
    components = {
        ":auth_service": "auth",
        ":data_service": "data",
        ":api_service": "api",
    },
)`},
			},
		},
		"wac_plug": {
			Name:        "wac_plug",
			Type:        "rule",
			Description: "Plug component exports into component imports using WAC. Automatically connects component exports to imports through WAC's plug functionality.",
			LoadFrom:    "@rules_wasm_component//wac:defs.bzl",
			Attributes: map[string]Attribute{
				"name":   {"string", true, nil, "A unique name for this target", nil},
				"socket": {"label", true, nil, "The socket component that imports functions", nil},
				"plugs":  {"label_list", true, nil, "The plug components that export functions", nil},
			},
			Examples: []Example{
				{"Component plugging", "Connect exports to imports automatically", `wac_plug(
    name = "connected_app",
    socket = ":main_component",
    plugs = [
        ":auth_plugin",
        ":storage_plugin",
    ],
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
		"wasm_sign": {
			Name:        "wasm_sign",
			Type:        "rule",
			Description: "Signs WebAssembly components using wasmsign2 for secure deployment. Provides cryptographic signatures for component integrity.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name":           {"string", true, nil, "A unique name for this target", nil},
				"component":      {"label", false, nil, "WebAssembly component to sign (alternative to wasm_file)", nil},
				"wasm_file":      {"label", false, nil, "WASM file to sign (alternative to component)", nil},
				"keys":           {"label", false, nil, "Key pair from wasm_keygen or ssh_keygen", nil},
				"secret_key":     {"label", false, nil, "Secret key file (alternative to keys)", nil},
				"detached":       {"bool", false, stringPtr("False"), "Create detached signature file", nil},
				"openssh_format": {"bool", false, stringPtr("False"), "Use OpenSSH key format (when not using keys attribute)", nil},
			},
			Examples: []Example{
				{"Sign component", "Sign a WebAssembly component with embedded signature", `wasm_sign(
    name = "signed_component",
    component = ":my_component",
    keys = ":signing_keys",
    detached = false,
)`},
			},
		},
		"wasm_verify": {
			Name:        "wasm_verify",
			Type:        "rule",
			Description: "Verifies signatures of signed WebAssembly components using wasmsign2. Validates component authenticity and integrity.",
			LoadFrom:    "@rules_wasm_component//wasm:defs.bzl",
			Attributes: map[string]Attribute{
				"name":             {"string", true, nil, "A unique name for this target", nil},
				"signed_component": {"label", false, nil, "Signed component to verify", nil},
				"wasm_file":        {"label", false, nil, "WASM file to verify (alternative to signed_component)", nil},
				"keys":             {"label", false, nil, "Public key from key pair", nil},
				"github_account":   {"string", false, nil, "GitHub account for key verification", nil},
				"split_regex":      {"string", false, nil, "Regular expression for partial verification", nil},
			},
			Examples: []Example{
				{"Verify component", "Verify a signed WebAssembly component", `wasm_verify(
    name = "verify_component",
    signed_component = ":signed_component",
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
		"wasm_component_wizer_library": {
			Name:        "wasm_component_wizer_library",
			Type:        "rule",
			Description: "Pre-initializes a WebAssembly component using Wizer library for improved startup performance. Executes initialization functions at build time to reduce runtime overhead.",
			LoadFrom:    "@rules_wasm_component//wasm:wasm_component_wizer_library.bzl",
			Attributes: map[string]Attribute{
				"name":               {"string", true, nil, "A unique name for this target", nil},
				"component":          {"label", true, nil, "Input WebAssembly component to pre-initialize", nil},
				"init_function_name": {"string", false, stringPtr("'wizer.initialize'"), "Name of the initialization function to call", nil},
				"allow_wasi":         {"bool", false, stringPtr("True"), "Allow WASI calls during initialization", nil},
				"verbose":            {"bool", false, nil, "Enable verbose output", nil},
			},
			Examples: []Example{
				{"Wizer optimization", "Pre-initialize a WebAssembly component", `wasm_component_wizer_library(
    name = "optimized_component",
    component = ":my_component",
    init_function_name = "wizer.initialize",
    allow_wasi = True,
)`},
			},
		},

		// ======================
		// RPC Rules
		// ======================
		"wrpc_bindgen": {
			Name:        "wrpc_bindgen",
			Type:        "rule",
			Description: "Generates language bindings for wrpc (WebAssembly Component RPC) from WIT interfaces. Creates client and server stubs for remote component communication.",
			LoadFrom:    "@rules_wasm_component//wrpc:defs.bzl",
			Attributes: map[string]Attribute{
				"name":     {"string", true, nil, "A unique name for this target", nil},
				"wit":      {"label", true, nil, "WIT file defining the interface", nil},
				"world":    {"string", true, nil, "WIT world to generate bindings for", nil},
				"language": {"string", false, stringPtr("'rust'"), "Target language for bindings", []string{"rust", "go"}},
			},
			Examples: []Example{
				{"RPC bindings", "Generate Rust RPC bindings from WIT", `wrpc_bindgen(
    name = "api_bindings",
    wit = "api.wit",
    world = "api-world",
    language = "rust",
)`},
			},
		},
		"wrpc_serve": {
			Name:        "wrpc_serve",
			Type:        "rule",
			Description: "Serves a WebAssembly component via wrpc for remote procedure calls. Creates executable scripts to run components as RPC servers.",
			LoadFrom:    "@rules_wasm_component//wrpc:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"component": {"label", true, nil, "WebAssembly component to serve", nil},
				"transport": {"string", false, stringPtr("'tcp'"), "Transport protocol", []string{"tcp", "nats"}},
				"address":   {"string", false, stringPtr("'0.0.0.0:8080'"), "Address to bind server to", nil},
			},
			Examples: []Example{
				{"Serve component", "Serve a component as RPC server", `wrpc_serve(
    name = "api_server",
    component = ":my_component",
    transport = "tcp",
    address = "0.0.0.0:8080",
)`},
			},
		},
		"wrpc_invoke": {
			Name:        "wrpc_invoke",
			Type:        "rule",
			Description: "Invokes functions on remote WebAssembly components via wrpc. Creates executable scripts to call remote component functions.",
			LoadFrom:    "@rules_wasm_component//wrpc:defs.bzl",
			Attributes: map[string]Attribute{
				"name":      {"string", true, nil, "A unique name for this target", nil},
				"function":  {"string", true, nil, "Function to invoke on remote component", nil},
				"transport": {"string", false, stringPtr("'tcp'"), "Transport protocol", []string{"tcp", "nats"}},
				"address":   {"string", false, stringPtr("'localhost:8080'"), "Address of the remote component", nil},
			},
			Examples: []Example{
				{"Invoke function", "Invoke a function on remote component", `wrpc_invoke(
    name = "call_api",
    function = "process-data",
    transport = "tcp",
    address = "localhost:8080",
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
