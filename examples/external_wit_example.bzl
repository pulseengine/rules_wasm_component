"""Example showing how to add external WIT dependencies to your project"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def load_external_wit_dependencies():
    """Load external WIT dependencies for your specific project"""

    # Method 1: Simple GitHub archive
    http_archive(
        name = "my_wit_interfaces",
        urls = ["https://github.com/myorg/wit-interfaces/archive/refs/tags/v1.2.3.tar.gz"],
        sha256 = "abcd1234...",  # Generate with: curl -L url | sha256sum
        strip_prefix = "wit-interfaces-1.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "api",
    srcs = glob(["wit/*.wit"]),
    package_name = "myorg:api@1.2.3",
    interfaces = ["http-client", "database"],
    deps = ["@wasi_io//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # Method 2: Multiple packages from same repository
    http_archive(
        name = "third_party_wit",
        urls = ["https://github.com/thirdparty/wasm-interfaces/archive/v2.0.0.tar.gz"],
        sha256 = "efgh5678...",
        strip_prefix = "wasm-interfaces-2.0.0",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# Package 1: Core types
wit_library(
    name = "types",
    srcs = glob(["core/wit/*.wit"]),
    package_name = "thirdparty:types@2.0.0",
    interfaces = ["base-types", "common"],
    visibility = ["//visibility:public"],
)

# Package 2: Extensions
wit_library(
    name = "extensions",
    srcs = glob(["extensions/wit/*.wit"]),
    package_name = "thirdparty:extensions@2.0.0",
    interfaces = ["advanced-api"],
    deps = [":types", "@wasi_io//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # Method 3: Custom WIT with build script
    http_archive(
        name = "generated_wit",
        urls = ["https://releases.example.com/wit-schemas/v1.0.0.tar.gz"],
        sha256 = "ijkl9012...",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# Process generated WIT files
genrule(
    name = "process_schemas",
    srcs = glob(["schemas/**/*.wit"]),
    outs = ["processed/api.wit"],
    cmd = "cat $(SRCS) > $@",  # Simple concatenation example
)

wit_library(
    name = "generated_api",
    srcs = [":process_schemas"],
    package_name = "generated:api@1.0.0",
    interfaces = ["auto-generated"],
    visibility = ["//visibility:public"],
)
""",
    )

# Step-by-step guide for your own dependency:

# 1. Find the WIT interfaces you want to use
#    - GitHub repository with .wit files
#    - Release archive or specific commit
#    - Note the package names declared in the .wit files

# 2. Get the SHA256 checksum:
#    curl -L https://github.com/myorg/my-wit/archive/v1.0.0.tar.gz | sha256sum

# 3. Create the http_archive rule:
def my_project_wit_deps():
    http_archive(
        name = "my_custom_wit",
        urls = ["https://github.com/myorg/my-wit/archive/v1.0.0.tar.gz"],
        sha256 = "your-calculated-sha256-here",
        strip_prefix = "my-wit-1.0.0",  # Remove the archive's top-level directory
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "my_interfaces",
    srcs = glob(["**/*.wit"]),  # Adjust glob pattern as needed
    package_name = "myorg:interfaces@1.0.0",  # Must match package declaration in .wit files
    interfaces = ["api", "types"],  # List the interfaces defined
    deps = [
        "@wasi_io//:streams",  # Add any WASI dependencies
        # "@other_wit_lib//:target",  # Add any other WIT dependencies
    ],
    visibility = ["//visibility:public"],
)
""",
    )

# 4. Load the dependency in your WORKSPACE or MODULE.bazel:
#    In WORKSPACE mode:
#      load("//path/to:external_wit_example.bzl", "my_project_wit_deps")
#      my_project_wit_deps()
#
#    In MODULE.bazel mode (recommended):
#      Add to your wasi_wit extension or create a new extension

# 5. Use in your BUILD files:
#    wit_library(
#        name = "my_component_wit",
#        srcs = ["my-component.wit"],
#        deps = [
#            "@my_custom_wit//:my_interfaces",
#            "@wasi_io//:streams",
#        ],
#    )
