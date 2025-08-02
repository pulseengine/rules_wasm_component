package main

import (
	"encoding/json"
	"fmt"
	"os"
)

// Schema definitions for our Bazel rules - AI agents can parse this
type RuleSchema struct {
	Name        string                   `json:"name"`
	Type        string                   `json:"type"` // "rule" or "provider"
	Description string                   `json:"description"`
	Attributes  map[string]Attribute     `json:"attributes,omitempty"`
	Fields      map[string]ProviderField `json:"fields,omitempty"`
	Examples    []Example                `json:"examples"`
	LoadFrom    string                   `json:"load_from"`
}

type Attribute struct {
	Type          string   `json:"type"`
	Required      bool     `json:"required"`
	Default       *string  `json:"default,omitempty"`
	Description   string   `json:"description"`
	AllowedValues []string `json:"allowed_values,omitempty"`
}

type ProviderField struct {
	Type        string `json:"type"`
	Description string `json:"description"`
}

type Example struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Code        string `json:"code"`
}

func main() {
	schemas := generateRuleSchemas()

	output, err := json.MarshalIndent(schemas, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating schemas: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(output))
}

func generateRuleSchemas() map[string]RuleSchema {
	return map[string]RuleSchema{
		"wit_library": {
			Name:        "wit_library",
			Type:        "rule",
			Description: "Defines a WIT (WebAssembly Interface Types) library. Processes WIT files and makes them available for use in WASM component builds and binding generation.",
			LoadFrom:    "@rules_wasm_component//wit:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {
					Type:        "string",
					Required:    true,
					Description: "A unique name for this target",
				},
				"srcs": {
					Type:        "label_list",
					Required:    true,
					Description: "WIT source files (*.wit)",
				},
				"package_name": {
					Type:        "string",
					Required:    false,
					Description: "WIT package name (e.g., 'my:package@1.0.0'). Defaults to target name if not specified.",
				},
				"deps": {
					Type:        "label_list",
					Required:    false,
					Description: "WIT library dependencies. Each dependency must provide WitInfo.",
				},
				"world": {
					Type:        "string",
					Required:    false,
					Description: "Optional world name to export from this library",
				},
				"interfaces": {
					Type:        "string_list",
					Required:    false,
					Description: "List of interface names defined in this library",
				},
			},
			Examples: []Example{
				{
					Title:       "Simple WIT library",
					Description: "Basic WIT library with a single interface file",
					Code: `wit_library(
    name = "my_interfaces",
    package_name = "my:pkg@1.0.0",
    srcs = ["interfaces.wit"],
)`,
				},
				{
					Title:       "WIT library with dependencies",
					Description: "WIT library that imports from another package",
					Code: `wit_library(
    name = "consumer_interfaces",
    package_name = "consumer:app@1.0.0",
    srcs = ["consumer.wit"],
    deps = ["//external:lib_interfaces"],
)`,
				},
			},
		},
		"rust_wasm_component_bindgen": {
			Name:        "rust_wasm_component_bindgen",
			Type:        "rule",
			Description: "Builds a Rust WebAssembly component with WIT binding generation. Compiles Rust source code into a WASM component and generates language bindings from WIT interfaces.",
			LoadFrom:    "@rules_wasm_component//rust:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {
					Type:        "string",
					Required:    true,
					Description: "A unique name for this target",
				},
				"srcs": {
					Type:        "label_list",
					Required:    true,
					Description: "Rust source files",
				},
				"wit": {
					Type:        "label",
					Required:    true,
					Description: "WIT library target that provides interfaces for this component",
				},
				"profiles": {
					Type:          "string_list",
					Required:      false,
					Default:       stringPtr("['release']"),
					Description:   "Build profiles to generate",
					AllowedValues: []string{"debug", "release", "custom"},
				},
				"deps": {
					Type:        "label_list",
					Required:    false,
					Description: "Rust dependencies (crates)",
				},
			},
			Examples: []Example{
				{
					Title:       "Basic Rust component",
					Description: "Simple Rust WASM component with WIT bindings",
					Code: `rust_wasm_component_bindgen(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":my_interfaces",
)`,
				},
				{
					Title:       "Multi-profile component",
					Description: "Component built with multiple optimization profiles",
					Code: `rust_wasm_component_bindgen(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":my_interfaces",
    profiles = ["debug", "release"],
)`,
				},
			},
		},
		"wac_compose": {
			Name:        "wac_compose",
			Type:        "rule",
			Description: "Composes multiple WebAssembly components into a single application using WAC (WebAssembly Composition) format.",
			LoadFrom:    "@rules_wasm_component//wac:defs.bzl",
			Attributes: map[string]Attribute{
				"name": {
					Type:        "string",
					Required:    true,
					Description: "A unique name for this target",
				},
				"components": {
					Type:        "string_dict",
					Required:    true,
					Description: "Map of component targets to component names in composition",
				},
				"composition": {
					Type:        "string",
					Required:    false,
					Description: "Inline WAC composition script",
				},
				"composition_file": {
					Type:        "label",
					Required:    false,
					Description: "WAC composition file (alternative to inline composition)",
				},
				"profile": {
					Type:        "string",
					Required:    false,
					Default:     stringPtr("'release'"),
					Description: "Build profile for components",
				},
			},
			Examples: []Example{
				{
					Title:       "Simple composition",
					Description: "Compose two components with inline WAC script",
					Code: `wac_compose(
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
)`,
				},
			},
		},
		"wit_deps_check": {
			Name:        "wit_deps_check",
			Type:        "rule",
			Description: "Analyzes a WIT file for missing dependencies and suggests fixes. Helps developers identify and resolve dependency issues.",
			LoadFrom:    "@rules_wasm_component//wit:wit_deps_check.bzl",
			Attributes: map[string]Attribute{
				"name": {
					Type:        "string",
					Required:    true,
					Description: "A unique name for this target",
				},
				"wit_file": {
					Type:        "label",
					Required:    true,
					Description: "WIT file to analyze for dependencies",
				},
			},
			Examples: []Example{
				{
					Title:       "Dependency analysis",
					Description: "Check a WIT file for missing dependencies",
					Code: `wit_deps_check(
    name = "check_deps",
    wit_file = "consumer.wit",
)`,
				},
			},
		},
		"WitInfo": {
			Name:        "WitInfo",
			Type:        "provider",
			Description: "Provider that contains information about WIT interfaces and their dependencies.",
			Fields: map[string]ProviderField{
				"wit_files": {
					Type:        "depset",
					Description: "Depset of WIT source files for this library",
				},
				"wit_deps": {
					Type:        "depset",
					Description: "Depset of transitive WIT dependencies",
				},
				"package_name": {
					Type:        "string",
					Description: "WIT package name (e.g., 'my:package@1.0.0')",
				},
				"world_name": {
					Type:        "string",
					Description: "World name exported by this library (optional)",
				},
				"interface_names": {
					Type:        "string_list",
					Description: "List of interface names defined in this library",
				},
			},
			Examples: []Example{
				{
					Title:       "Using WitInfo in custom rules",
					Description: "Access WIT metadata in rule implementations",
					Code: `def _my_rule_impl(ctx):
    wit_info = ctx.attr.wit[WitInfo]
    package_name = wit_info.package_name
    wit_files = wit_info.wit_files.to_list()
    # Use wit_info...`,
				},
			},
		},
	}
}

func stringPtr(s string) *string {
	return &s
}
