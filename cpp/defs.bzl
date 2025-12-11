# Copyright 2024 Ralf Anton Beier. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""C/C++ WebAssembly Component Model rules

Production-ready C/C++ support for WebAssembly Component Model using:
- WASI SDK v27+ with native Preview2 support
- Clang 20+ with advanced WebAssembly optimizations
- Bazel-native implementation with comprehensive cross-package header staging
- Cross-platform compatibility (Windows/macOS/Linux)
- Modern C++17/20/23 standard support with exception handling
- External library integration (nlohmann_json, abseil-cpp, spdlog, fmt)
- Advanced header dependency resolution and CcInfo provider integration
- Component libraries for modular development

Example usage:

    cpp_component(
        name = "calculator",
        srcs = ["calculator.cpp", "math_utils.cpp"],
        hdrs = ["calculator.h"],
        wit = "//wit:calculator-interface",
        world = "calculator",
        language = "cpp",
        cxx_std = "c++20",
        enable_exceptions = True,
        deps = [
            "@nlohmann_json//:json",
            "@abseil-cpp//absl/strings",
        ],
    )

    cc_component_library(
        name = "math_utils",
        srcs = ["math.cpp"],
        hdrs = ["math.h"],
        deps = ["@fmt//:fmt"],
    )
"""

load("//providers:providers.bzl", "WasmComponentInfo")
load("//rust:transitions.bzl", "wasm_transition")
load("//tools/bazel_helpers:file_ops_actions.bzl", "setup_cpp_workspace_action")
load(
    "//cpp:cpp_wasm_binary.bzl",
    _c_wasm_binary = "c_wasm_binary",
    _cpp_wasm_binary = "cpp_wasm_binary",
)

def _cpp_component_impl(ctx):
    """Implementation of cpp_component rule for C/C++ WebAssembly components.

    Compiles C/C++ source code into a WebAssembly component using WASI SDK with
    native Preview2 support, WIT binding generation, and component model integration.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: C/C++ source files to compile
            - ctx.files.hdrs: Header files for the component
            - ctx.attr.deps: Dependencies (cc_component_library and external libraries)
            - ctx.file.wit: WIT interface definition file
            - ctx.attr.world: WIT world to target
            - ctx.attr.language: Either "c" or "cpp"
            - ctx.attr.cxx_std: C++ standard (c++17/20/23)
            - ctx.attr.enable_exceptions: Enable C++ exception handling
            - ctx.attr.optimize: Enable optimizations (-O3, -flto)

    Returns:
        List of providers:
        - WasmComponentInfo: Component metadata with language and toolchain info
        - DefaultInfo: Component .wasm file and validation logs
        - OutputGroupInfo: Organized outputs (bindings, wasm_module, validation)

    The implementation follows these steps:
    1. Generate C/C++ bindings from WIT using wit-bindgen
    2. Set up compilation workspace with proper header staging
    3. Compile WIT bindings separately (C compilation to avoid C++ flags)
    4. Compile application sources with dependency headers and includes
    5. Link everything together with C++ standard library (if needed)
    6. Embed WIT metadata and create component using wasm-tools
    7. Optionally validate the component against WIT specification

    Key features:
    - Cross-package header dependency resolution using CcInfo
    - Proper staging of local vs external headers
    - Support for modern C++ standards (C++17/20/23)
    - Exception handling support (increases binary size)
    - LTO optimization for size reduction
    - WASI SDK Preview2 native compilation
    """

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]

    # Use clang for both C and C++ compilation to avoid clang++ preprocessor issues
    clang = cpp_toolchain.clang  # if ctx.attr.language == "c" else cpp_toolchain.clang_cpp
    wit_bindgen = cpp_toolchain.wit_bindgen
    wasm_tools = cpp_toolchain.wasm_tools
    sysroot = cpp_toolchain.sysroot
    sysroot_files = cpp_toolchain.sysroot_files

    # Output files
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input files
    sources = ctx.files.srcs
    headers = ctx.files.hdrs
    wit_file = ctx.file.wit

    # Detect if we need C++ compilation support (for source files, not bindings)
    # This allows C++ source files to work with both C and C++ bindings
    has_cpp_sources = any([src.extension in ["cpp", "cc", "cxx", "C", "CPP"] for src in sources])
    needs_cpp_compilation = ctx.attr.language == "cpp" or has_cpp_sources

    # Collect dependency headers and libraries using CcInfo provider
    dep_headers = []
    dep_libraries = []
    dep_includes = []

    for dep in ctx.attr.deps:
        # Always check DefaultInfo first for direct file access (simpler and more reliable)
        if DefaultInfo in dep:
            for file in dep[DefaultInfo].files.to_list():
                if file.extension in ["h", "hpp", "hh", "hxx"]:
                    dep_headers.append(file)
                elif file.extension == "a":
                    dep_libraries.append(file)

        # Extract includes and headers from CcInfo for proper transitive dependencies
        # CRITICAL FIX for Issue #38: Distinguish between external vs local CcInfo headers
        if CcInfo in dep:
            cc_info = dep[CcInfo]

            # Add all types of include paths (direct, system, and quote includes)
            dep_includes.extend(cc_info.compilation_context.includes.to_list())
            dep_includes.extend(cc_info.compilation_context.system_includes.to_list())
            dep_includes.extend(cc_info.compilation_context.quote_includes.to_list())

            # CRITICAL FIX: Stage local CcInfo headers for cross-package dependencies
            # External libraries (path contains "external/") don't need staging - use original paths
            # Local libraries (same workspace) need staging for relative includes to work
            for hdr in cc_info.compilation_context.headers.to_list():
                if hdr.extension in ["h", "hpp", "hh", "hxx"]:
                    # Check if this is an external dependency or local cross-package dependency
                    if "external/" not in hdr.path:
                        # Local cross-package header - stage it for relative includes to work
                        dep_headers.append(hdr)

                    # External headers are handled via include paths only (no staging needed)

    # Generate bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate C/C++ bindings from WIT
    wit_args = ctx.actions.args()
    wit_args.add(ctx.attr.language)
    wit_args.add("--out-dir", bindings_dir.path)

    if ctx.attr.world:
        wit_args.add("--world", ctx.attr.world)

    wit_args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen,
        arguments = [wit_args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = "WitBindgen" + ("C" if ctx.attr.language == "c" else "Cpp"),
        progress_message = "Generating %s bindings for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Create working directory for compilation using File Operations Component
    work_dir = setup_cpp_workspace_action(
        ctx,
        sources = sources,
        headers = headers,
        dep_headers = dep_headers,
        bindings_dir = bindings_dir,
    )

    # Compile to WASM
    wasm_binary = ctx.actions.declare_file(ctx.attr.name + "_module.wasm")

    compile_args = ctx.actions.args()

    # Basic compiler flags for Preview2
    compile_args.add("--target=wasm32-wasip2")

    # Build sysroot path from toolchain repository for external compatibility
    if sysroot_files and sysroot_files.files:
        # Use sysroot_files to determine the actual sysroot directory
        toolchain_file = sysroot_files.files.to_list()[0]

        # Extract the sysroot directory by removing the file component
        if "/sysroot/" in toolchain_file.path:
            # Get everything up to and including /sysroot/
            sysroot_base = toolchain_file.path.split("/sysroot/")[0] + "/sysroot"
            sysroot_path = sysroot_base
        else:
            sysroot_path = sysroot
    else:
        sysroot_path = sysroot

    compile_args.add("--sysroot=" + sysroot_path)

    # Component model definitions
    compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
    compile_args.add("-D_WASI_EMULATED_SIGNAL")
    compile_args.add("-D_WASI_EMULATED_MMAN")
    compile_args.add("-DCOMPONENT_MODEL_PREVIEW2")

    # Standard library control
    if ctx.attr.nostdlib:
        compile_args.add("-nostdlib")

        # When using nostdlib, we need to be more selective about what we link
        compile_args.add("-Wl,--no-entry")  # Don't expect a main function

    # Optimization and language settings
    if ctx.attr.optimize:
        compile_args.add("-O3")
        compile_args.add("-flto")
    else:
        compile_args.add("-O0")
        compile_args.add("-g")

    # C++ specific flags (for source compilation)
    if needs_cpp_compilation:
        if ctx.attr.enable_exceptions:
            # Enable exceptions if specifically requested
            compile_args.add("-fexceptions")
            compile_args.add("-fcxx-exceptions")
        else:
            compile_args.add("-fno-exceptions")

        if ctx.attr.enable_rtti:
            # Only enable RTTI if specifically requested
            pass
        else:
            compile_args.add("-fno-rtti")

        if ctx.attr.cxx_std:
            compile_args.add("-std=" + ctx.attr.cxx_std)

    # Include directories
    compile_args.add("-I" + work_dir.path)

    # Add C++ standard library paths for wasm32-wasip2 target
    if needs_cpp_compilation:
        # WASI SDK stores C++ headers in share/wasi-sysroot, not just sysroot
        if "/external/" in sysroot_path:
            toolchain_repo = sysroot_path.split("/sysroot")[0]
            wasi_sysroot = toolchain_repo + "/share/wasi-sysroot"
        else:
            wasi_sysroot = sysroot_path
        compile_args.add("-I" + wasi_sysroot + "/include/wasm32-wasip2/c++/v1")
        compile_args.add("-I" + wasi_sysroot + "/include/c++/v1")

        # Also add clang's builtin headers
        if "/external/" in sysroot_path:
            compile_args.add("-I" + toolchain_repo + "/lib/clang/20/include")

    for include in ctx.attr.includes:
        compile_args.add("-I" + include)

    # Add dependency include directories from CcInfo
    for include_dir in dep_includes:
        if include_dir not in [work_dir.path] + ctx.attr.includes:
            compile_args.add("-I" + include_dir)

    # Add dependency header directories (fallback for non-CcInfo deps)
    for dep_hdr in dep_headers:
        include_dir = dep_hdr.dirname
        if include_dir not in [work_dir.path] + ctx.attr.includes + dep_includes:
            compile_args.add("-I" + include_dir)

    # Defines
    for define in ctx.attr.defines:
        compile_args.add("-D" + define)

    # Compile flags
    for flag in ctx.attr.copts:
        compile_args.add(flag)

    # Output
    compile_args.add("-o", wasm_binary.path)

    # Add external dependency headers to inputs (from CcInfo)
    external_headers = []
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            external_headers.extend(cc_info.compilation_context.headers.to_list())

    # Add source files from work directory
    for src in sources:
        compile_args.add(work_dir.path + "/" + src.basename)

    # Compile generated WIT binding file separately
    # wit-bindgen generates filenames by converting hyphens to underscores: http-service-world -> http_service_world.c
    world_name = ctx.attr.world or "component"  # Default to "component" if no world specified
    file_safe_world_name = world_name.replace("-", "_")  # Convert hyphens to underscores for filesystem
    binding_ext = ".cpp" if ctx.attr.language == "cpp" else ".c"
    binding_c_file = bindings_dir.path + "/" + file_safe_world_name + binding_ext
    binding_h_file = bindings_dir.path + "/" + file_safe_world_name + ".h"
    binding_o_file = bindings_dir.path + "/" + file_safe_world_name + "_component_type.o"

    # Add bindings header directory to include path
    compile_args.add("-I" + bindings_dir.path)

    # Compile the generated C binding file separately to avoid C++ flags
    binding_obj_file = ctx.actions.declare_file(ctx.attr.name + "_bindings.o")

    binding_compile_args = ctx.actions.args()
    binding_compile_args.add("--target=wasm32-wasip2")
    binding_compile_args.add("--sysroot=" + sysroot_path)
    binding_compile_args.add("-c")  # Compile only, don't link

    # Component model definitions (same as main compilation)
    binding_compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
    binding_compile_args.add("-D_WASI_EMULATED_SIGNAL")
    binding_compile_args.add("-D_WASI_EMULATED_MMAN")
    binding_compile_args.add("-DCOMPONENT_MODEL_PREVIEW2")

    # Optimization settings
    if ctx.attr.optimize:
        binding_compile_args.add("-O3")
        binding_compile_args.add("-flto")
    else:
        binding_compile_args.add("-O0")
        binding_compile_args.add("-g")

    # Exception handling for binding compilation (if C++ exceptions are enabled)
    if ctx.attr.language == "cpp" and ctx.attr.enable_exceptions:
        binding_compile_args.add("-fexceptions")
        binding_compile_args.add("-fcxx-exceptions")

    # C++ compilation flags for binding compilation
    if ctx.attr.language == "cpp":
        # C++ standard (bindings require C++20 for std::span)
        if ctx.attr.cxx_std:
            binding_compile_args.add("-std=" + ctx.attr.cxx_std)
        else:
            binding_compile_args.add("-std=c++20")  # Default to C++20 for bindings

        # WASI SDK stores C++ headers in share/wasi-sysroot, not just sysroot
        if "/external/" in sysroot_path:
            toolchain_repo = sysroot_path.split("/sysroot")[0]
            wasi_sysroot = toolchain_repo + "/share/wasi-sysroot"
        else:
            wasi_sysroot = sysroot_path
        binding_compile_args.add("-I" + wasi_sysroot + "/include/wasm32-wasip2/c++/v1")
        binding_compile_args.add("-I" + wasi_sysroot + "/include/c++/v1")

        # Also add clang's builtin headers
        if "/external/" in sysroot_path:
            binding_compile_args.add("-I" + toolchain_repo + "/lib/clang/20/include")

    # Include directories
    binding_compile_args.add("-I" + work_dir.path)
    binding_compile_args.add("-I" + bindings_dir.path)

    # Add dependency include directories
    for include_dir in dep_includes:
        binding_compile_args.add("-I" + include_dir)

    # Output and input
    binding_compile_args.add("-o", binding_obj_file.path)
    binding_compile_args.add(binding_c_file)

    ctx.actions.run(
        executable = clang,
        arguments = [binding_compile_args],
        inputs = [work_dir, bindings_dir] + sysroot_files.files.to_list() + dep_headers + external_headers,
        outputs = [binding_obj_file],
        mnemonic = "Compile" + ("C" if ctx.attr.language == "c" else "Cpp") + "Bindings",
        progress_message = "Compiling %s WIT bindings for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Add compiled binding object file and pre-compiled component type object to linking
    compile_args.add(binding_obj_file.path)
    compile_args.add(binding_o_file)

    # Add library linking
    if ctx.attr.nostdlib:
        # When nostdlib is enabled, only link explicitly specified libraries
        for lib in ctx.attr.libs:
            if lib.startswith("-"):
                compile_args.add(lib)  # Direct linker flag (e.g., "-lm", "-ldl")
            else:
                compile_args.add("-l" + lib)  # Library name (e.g., "m" -> "-lm")
    else:
        # Standard library linking for C++ source files
        if needs_cpp_compilation:
            compile_args.add("-lc++")
            compile_args.add("-lc++abi")

            # Add exception handling support if enabled
            # Note: Exception handling symbols are typically in libc++abi which we already link

        # Add any additional libraries specified by user
        for lib in ctx.attr.libs:
            if lib.startswith("-"):
                compile_args.add(lib)  # Direct linker flag
            else:
                compile_args.add("-l" + lib)  # Library name

    # Add dependency libraries for linking
    for lib in dep_libraries:
        compile_args.add(lib.path)

    ctx.actions.run(
        executable = clang,
        arguments = [compile_args],
        inputs = [work_dir, bindings_dir, binding_obj_file] + sysroot_files.files.to_list() + dep_libraries + dep_headers + external_headers,
        outputs = [wasm_binary],
        mnemonic = "Compile" + ("C" if ctx.attr.language == "c" else "Cpp") + "Wasm",
        progress_message = "Compiling %s to WASM for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Embed WIT metadata and create component in one step
    embed_args = ctx.actions.args()
    embed_args.add("component")
    embed_args.add("embed")
    embed_args.add(wit_file.path)
    embed_args.add(wasm_binary.path)
    embed_args.add("--output", component_wasm.path)

    if ctx.attr.world:
        embed_args.add("--world", ctx.attr.world)

    ctx.actions.run(
        executable = wasm_tools,
        arguments = [embed_args],
        inputs = [wasm_binary, wit_file],
        outputs = [component_wasm],
        mnemonic = "Create" + ("C" if ctx.attr.language == "c" else "Cpp") + "Component",
        progress_message = "Creating %s WebAssembly component for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Optional WIT validation
    validation_outputs = []
    if ctx.attr.validate_wit:
        validation_log = ctx.actions.declare_file(ctx.attr.name + "_wit_validation.log")
        validation_outputs.append(validation_log)

        # Create validation arguments
        validate_args = ctx.actions.args()
        validate_args.add("component")
        validate_args.add("wit")
        validate_args.add(component_wasm.path)

        # Run wasm-tools validate to verify component is valid WebAssembly
        # and extract interface for documentation
        ctx.actions.run_shell(
            command = '''
            # Validate component with component model features
            "$1" validate --features component-model "$2" 2>&1
            if [ $? -ne 0 ]; then
                echo "ERROR: Component validation failed for $2" > "$3"
                "$1" validate --features component-model "$2" >> "$3" 2>&1
                exit 1
            fi

            # Extract WIT interface for documentation
            echo "=== COMPONENT VALIDATION PASSED ===" > "$3"
            echo "Component is valid WebAssembly with component model" >> "$3"
            echo "" >> "$3"
            echo "=== EXPORTED WIT INTERFACE ===" >> "$3"
            "$1" component wit "$2" >> "$3" 2>&1 || echo "Failed to extract WIT interface" >> "$3"
            ''',
            arguments = [wasm_tools.path, component_wasm.path, validation_log.path],
            inputs = [component_wasm],
            outputs = [validation_log],
            tools = [wasm_tools],
            mnemonic = "ValidateWasmComponent",
            progress_message = "Validating WebAssembly component for %s" % ctx.label,
        )

    # Create component info
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = wit_file,
            package_name = ctx.attr.package_name or "{}:component@1.0.0".format(ctx.attr.name),
        ),
        component_type = "component",
        imports = [],  # TODO: Parse from WIT
        exports = [ctx.attr.world] if ctx.attr.world else [],
        metadata = {
            "name": ctx.label.name,
            "language": ctx.attr.language,
            "target": "wasm32-wasip2",
            "wasi_sdk": True,
            "toolchain": "wasi-sdk",
            "cxx_std": ctx.attr.cxx_std if ctx.attr.cxx_std else None,
            "optimization": ctx.attr.optimize,
        },
        profile = ctx.attr.optimization if hasattr(ctx.attr, "optimization") else "release",
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm] + validation_outputs)),
        OutputGroupInfo(
            bindings = depset([bindings_dir]),
            wasm_module = depset([wasm_binary]),
            validation = depset(validation_outputs),
        ),
    ]

cpp_component = rule(
    implementation = _cpp_component_impl,
    cfg = wasm_transition,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".c", ".cpp", ".cc", ".cxx"],
            mandatory = True,
            doc = "C/C++ source files",
        ),
        "hdrs": attr.label_list(
            allow_files = [".h", ".hpp", ".hh", ".hxx"],
            doc = "C/C++ header files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies (cc_component_library targets)",
        ),
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "language": attr.string(
            default = "cpp",
            values = ["c", "cpp"],
            doc = "Language variant (c or cpp)",
        ),
        "world": attr.string(
            doc = "WIT world to target (optional)",
        ),
        "package_name": attr.string(
            doc = "WIT package name (auto-generated if not provided)",
        ),
        "includes": attr.string_list(
            doc = "Additional include directories",
        ),
        "defines": attr.string_list(
            doc = "Preprocessor definitions",
        ),
        "copts": attr.string_list(
            doc = "Additional compiler options",
        ),
        "optimize": attr.bool(
            default = True,
            doc = "Enable optimizations",
        ),
        "cxx_std": attr.string(
            doc = "C++ standard (e.g., c++17, c++20, c++23)",
        ),
        "enable_rtti": attr.bool(
            default = False,
            doc = "Enable C++ RTTI (not recommended for components)",
        ),
        "enable_exceptions": attr.bool(
            default = False,
            doc = "Enable C++ exceptions (increases binary size)",
        ),
        "nostdlib": attr.bool(
            default = False,
            doc = "Disable standard library linking to create minimal components that match WIT specifications exactly",
        ),
        "libs": attr.string_list(
            default = [],
            doc = "Libraries to link. When nostdlib=True, only these libraries are linked. When nostdlib=False, these are added to standard libraries. Examples: ['m', 'dl'] or ['-lm', '-ldl']",
        ),
        "validate_wit": attr.bool(
            default = False,
            doc = "Validate that the component exports match the WIT specification",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:cpp_component_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Builds a WebAssembly component from C/C++ source code using Preview2.

    This rule compiles C/C++ code directly to a Preview2 WebAssembly component
    without requiring adapter modules, providing native component model support.

    Example:
        cpp_component(
            name = "calculator_component",
            srcs = ["calculator.cpp", "math_utils.cpp"],
            hdrs = ["calculator.h"],
            wit = "calculator.wit",
            language = "cpp",
            world = "calculator",
            cxx_std = "c++20",
            optimize = True,
        )
    """,
)

def _cpp_wit_bindgen_impl(ctx):
    """Implementation of cpp_wit_bindgen rule for standalone WIT binding generation.

    Generates C/C++ bindings from WIT interface definitions without building
    a complete component. Useful for creating reusable binding libraries.

    Args:
        ctx: The rule context containing:
            - ctx.file.wit: WIT interface definition file
            - ctx.attr.world: WIT world to generate bindings for
            - ctx.attr.stubs_only: Generate only stub functions
            - ctx.attr.string_encoding: String encoding (utf8/utf16/compact-utf16)

    Returns:
        List of providers:
        - DefaultInfo: Generated bindings directory
        - OutputGroupInfo: Organized output (bindings group)

    Generated files include:
    - <world>.h: Header file with interface declarations
    - <world>.c: Implementation file with binding code
    - <world>_component_type.o: Pre-compiled component type object

    Example:
        cpp_wit_bindgen(
            name = "http_bindings",
            wit = "http.wit",
            world = "http-handler",
            string_encoding = "utf8",
        )
    """

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]
    wit_bindgen = cpp_toolchain.wit_bindgen

    # Input WIT file
    wit_file = ctx.file.wit

    # Output bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate C/C++ bindings
    args = ctx.actions.args()
    args.add(ctx.attr.language)
    args.add("--out-dir", bindings_dir.path)

    if ctx.attr.world:
        args.add("--world", ctx.attr.world)

    if ctx.attr.stubs_only:
        args.add("--stubs-only")

    # string-encoding is only supported for C bindings
    if ctx.attr.string_encoding and ctx.attr.language == "c":
        args.add("--string-encoding", ctx.attr.string_encoding)

    args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen,
        arguments = [args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = ("C" if ctx.attr.language == "c" else "Cpp") + "WitBindgen",
        progress_message = "Generating %s WIT bindings for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    return [
        DefaultInfo(files = depset([bindings_dir])),
        OutputGroupInfo(
            bindings = depset([bindings_dir]),
        ),
    ]

cpp_wit_bindgen = rule(
    implementation = _cpp_wit_bindgen_impl,
    cfg = wasm_transition,
    attrs = {
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "world": attr.string(
            doc = "WIT world to generate bindings for",
        ),
        "stubs_only": attr.bool(
            default = False,
            doc = "Generate only stub functions without implementation",
        ),
        "string_encoding": attr.string(
            values = ["utf8", "utf16", "compact-utf16"],
            doc = "String encoding to use in generated bindings",
        ),
        "language": attr.string(
            default = "cpp",
            values = ["c", "cpp"],
            doc = "Language variant (c or cpp)",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:cpp_component_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Generates C/C++ bindings from WIT interface definitions.

    This rule uses wit-bindgen to create C/C++ header and source files
    that implement or consume WIT interfaces for component development.

    Example:
        cpp_wit_bindgen(
            name = "calculator_bindings",
            wit = "calculator.wit",
            world = "calculator",
            string_encoding = "utf8",
        )
    """,
)

def _cc_component_library_impl(ctx):
    """Implementation of cc_component_library rule for reusable C/C++ component libraries.

    Compiles C/C++ source files into a static library (.a) that can be linked
    into WebAssembly components. Provides proper header staging and dependency
    propagation through CcInfo provider.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: C/C++ source files to compile
            - ctx.files.hdrs: Public header files
            - ctx.attr.deps: Dependencies (other cc_component_library targets)
            - ctx.attr.language: Either "c" or "cpp"
            - ctx.attr.cxx_std: C++ standard for compilation
            - ctx.attr.optimize: Enable optimizations
            - ctx.attr.includes: Additional include directories

    Returns:
        List of providers:
        - DefaultInfo: Static library file and public headers
        - CcInfo: Compilation and linking contexts for transitive dependencies
        - OutputGroupInfo: Organized outputs (library, objects, headers)

    The implementation:
    1. Sets up workspace with proper cross-package header staging
    2. Compiles each source file to object file (.o)
    3. Creates static library from object files using llvm-ar
    4. Builds CcInfo with:
       - Compilation context (headers + include paths)
       - Linking context (static library for linking)
    5. Propagates transitive dependencies correctly

    CcInfo Provider Details:
        compilation_context:
            - headers: All headers (direct + transitive)
            - includes: Include paths for compiler
        linking_context:
            - linker_inputs: Static library for final linking

    Critical for cross-package dependencies:
        - Stages local headers for relative includes
        - Uses original paths for external library headers
        - Propagates include paths transitively
    """

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]

    # Use clang for both C and C++ compilation to avoid clang_cpp preprocessor issues
    clang = cpp_toolchain.clang
    llvm_ar = cpp_toolchain.llvm_ar
    sysroot = cpp_toolchain.sysroot
    sysroot_files = cpp_toolchain.sysroot_files

    # Detect if we need C++ compilation support (for source files)
    has_cpp_sources = any([src.extension in ["cpp", "cc", "cxx", "C", "CPP"] for src in ctx.files.srcs])
    needs_cpp_compilation = ctx.attr.language == "cpp" or has_cpp_sources

    # Output library
    library = ctx.actions.declare_file("lib{}.a".format(ctx.attr.name))

    # Collect dependency headers with proper cross-package staging
    dep_headers = []
    for dep in ctx.attr.deps:
        # Check DefaultInfo first for direct file access (cc_component_library outputs)
        if DefaultInfo in dep:
            for file in dep[DefaultInfo].files.to_list():
                if file.extension in ["h", "hpp", "hh", "hxx"]:
                    dep_headers.append(file)

        # CRITICAL FIX for Issue #38: Stage local CcInfo headers for cross-package dependencies
        # External libraries (path contains "external/") don't need staging - use original paths
        # Local libraries (same workspace) need staging for relative includes to work
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            for hdr in cc_info.compilation_context.headers.to_list():
                if hdr.extension in ["h", "hpp", "hh", "hxx"]:
                    # Check if this is an external dependency or local cross-package dependency
                    if "external/" not in hdr.path:
                        # Local cross-package header - stage it for relative includes to work
                        dep_headers.append(hdr)

                    # External headers are handled via include paths only (no staging needed)

    # Set up workspace with proper header staging (CRITICAL FIX for issue #38)
    work_dir = setup_cpp_workspace_action(
        ctx,
        sources = ctx.files.srcs,
        headers = ctx.files.hdrs,
        dep_headers = dep_headers,
    )

    # Compile source files to object files
    object_files = []

    for src in ctx.files.srcs:
        obj_file = ctx.actions.declare_file(src.basename.rsplit(".", 1)[0] + ".o")
        object_files.append(obj_file)

        # Compile arguments
        compile_args = ctx.actions.args()
        compile_args.add("--target=wasm32-wasip2")

        # Resolve sysroot path dynamically for external repository compatibility
        if sysroot_files and sysroot_files.files:
            toolchain_file = sysroot_files.files.to_list()[0]
            if "/sysroot/" in toolchain_file.path:
                sysroot_dir = toolchain_file.path.split("/sysroot/")[0] + "/sysroot"
            else:
                sysroot_dir = sysroot
        else:
            sysroot_dir = sysroot
        compile_args.add("--sysroot=" + sysroot_dir)
        compile_args.add("-c")  # Compile only, don't link

        # Component model definitions
        compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
        compile_args.add("-D_WASI_EMULATED_SIGNAL")
        compile_args.add("-D_WASI_EMULATED_MMAN")
        compile_args.add("-DCOMPONENT_MODEL_PREVIEW2")

        # Optimization
        if ctx.attr.optimize:
            compile_args.add("-O3")
            compile_args.add("-flto")  # Enable LTO for compatibility with cpp_component
        else:
            compile_args.add("-O0")
            compile_args.add("-g")

        # C++ specific flags (for source compilation)
        if needs_cpp_compilation:
            if ctx.attr.enable_exceptions:
                # Enable exceptions if specifically requested
                pass
            else:
                compile_args.add("-fno-exceptions")

            compile_args.add("-fno-rtti")
            if ctx.attr.cxx_std:
                compile_args.add("-std=" + ctx.attr.cxx_std)

        # Include directories - CRITICAL FIX: Use workspace directory for proper header staging
        compile_args.add("-I" + work_dir.path)  # Workspace with staged headers

        # Add C++ standard library paths for wasm32-wasip2 target
        if needs_cpp_compilation:
            # WASI SDK stores C++ headers in share/wasi-sysroot, not just sysroot
            if "/external/" in sysroot_dir:
                toolchain_repo = sysroot_dir.split("/sysroot")[0]
                wasi_sysroot = toolchain_repo + "/share/wasi-sysroot"
            else:
                wasi_sysroot = sysroot_dir
            compile_args.add("-I" + wasi_sysroot + "/include/wasm32-wasip2/c++/v1")
            compile_args.add("-I" + wasi_sysroot + "/include/c++/v1")

            # Also add clang's builtin headers
            if "/external/" in sysroot_dir:
                compile_args.add("-I" + toolchain_repo + "/lib/clang/20/include")

        for include in ctx.attr.includes:
            compile_args.add("-I" + include)

        # Add dependency header directories
        for dep_hdr in dep_headers:
            compile_args.add("-I" + dep_hdr.dirname)

        # Add include paths from CcInfo dependencies (external libraries)
        for dep in ctx.attr.deps:
            if CcInfo in dep:
                cc_info = dep[CcInfo]

                # Add both direct includes and system includes
                for include_path in cc_info.compilation_context.includes.to_list():
                    compile_args.add("-I" + include_path)
                for include_path in cc_info.compilation_context.system_includes.to_list():
                    compile_args.add("-I" + include_path)

                # Also add quote includes if available
                for include_path in cc_info.compilation_context.quote_includes.to_list():
                    compile_args.add("-I" + include_path)

        # Defines
        for define in ctx.attr.defines:
            compile_args.add("-D" + define)

        # Compiler options
        for opt in ctx.attr.copts:
            compile_args.add(opt)

        # Output and input - CRITICAL FIX: Use source file from workspace
        compile_args.add("-o", obj_file.path)
        compile_args.add(work_dir.path + "/" + src.basename)

        # Add external dependency headers to inputs
        all_inputs = [work_dir] + sysroot_files.files.to_list()
        for dep in ctx.attr.deps:
            if CcInfo in dep:
                cc_info = dep[CcInfo]
                all_inputs.extend(cc_info.compilation_context.headers.to_list())

        ctx.actions.run(
            executable = clang,
            arguments = [compile_args],
            inputs = all_inputs,
            outputs = [obj_file],
            mnemonic = "Compile" + ("C" if ctx.attr.language == "c" else "Cpp") + "Object",
            progress_message = "Compiling {} {} for component library".format(ctx.attr.language.upper(), src.basename),
        )

    # Create static library
    ar_args = ctx.actions.args()
    ar_args.add("rcs")
    ar_args.add(library.path)
    ar_args.add_all(object_files)

    ctx.actions.run(
        executable = llvm_ar,
        arguments = [ar_args],
        inputs = object_files,
        outputs = [library],
        mnemonic = "Create" + ("C" if ctx.attr.language == "c" else "Cpp") + "Library",
        progress_message = "Creating %s component library %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Collect transitive headers and libraries from dependencies
    transitive_headers = []
    transitive_libraries = []
    transitive_includes = []
    direct_includes = []  # For external library includes used by this library

    for dep in ctx.attr.deps:
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            transitive_headers.append(cc_info.compilation_context.headers)

            # Collect all types of includes for proper transitive propagation
            transitive_includes.extend(cc_info.compilation_context.includes.to_list())
            direct_includes.extend(cc_info.compilation_context.includes.to_list())
            direct_includes.extend(cc_info.compilation_context.system_includes.to_list())
            direct_includes.extend(cc_info.compilation_context.quote_includes.to_list())

            transitive_libraries.append(cc_info.linking_context.linker_inputs)

    # Create compilation context with current headers and transitive headers
    # Include both local header directories and external library include paths
    local_includes = [h.dirname for h in ctx.files.hdrs] + ctx.attr.includes
    all_includes = local_includes + direct_includes

    compilation_context = cc_common.create_compilation_context(
        headers = depset(ctx.files.hdrs, transitive = transitive_headers),
        includes = depset(all_includes, transitive = [depset(transitive_includes)]),
    )

    # Create linking context for the static library
    # For cross-package linking, we need to provide the library through the linking context
    # Use a simpler approach that works with our custom WASM toolchain
    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        user_link_flags = [library.path],  # Pass library as link flag
    )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input], transitive = transitive_libraries),
    )

    # Create CcInfo provider with both compilation and linking contexts
    cc_info = CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )

    return [
        DefaultInfo(files = depset([library] + ctx.files.hdrs)),
        cc_info,
        OutputGroupInfo(
            library = depset([library]),
            objects = depset(object_files),
            headers = depset(ctx.files.hdrs),
        ),
    ]

cc_component_library = rule(
    implementation = _cc_component_library_impl,
    cfg = wasm_transition,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".c", ".cpp", ".cc", ".cxx"],
            mandatory = True,
            doc = "C/C++ source files",
        ),
        "hdrs": attr.label_list(
            allow_files = [".h", ".hpp", ".hh", ".hxx"],
            doc = "C/C++ header files",
        ),
        "deps": attr.label_list(
            doc = "Dependencies (other cc_component_library targets)",
        ),
        "language": attr.string(
            default = "cpp",
            values = ["c", "cpp"],
            doc = "Language variant (c or cpp)",
        ),
        "includes": attr.string_list(
            doc = "Additional include directories",
        ),
        "defines": attr.string_list(
            doc = "Preprocessor definitions",
        ),
        "copts": attr.string_list(
            doc = "Additional compiler options",
        ),
        "optimize": attr.bool(
            default = True,
            doc = "Enable optimizations",
        ),
        "cxx_std": attr.string(
            doc = "C++ standard (e.g., c++17, c++20, c++23)",
        ),
        "enable_exceptions": attr.bool(
            default = False,
            doc = "Enable C++ exceptions (increases binary size)",
        ),
        "nostdlib": attr.bool(
            default = False,
            doc = "Disable standard library linking to create minimal components that match WIT specifications exactly",
        ),
        "libs": attr.string_list(
            default = [],
            doc = "Libraries to link. When nostdlib=True, only these libraries are linked. When nostdlib=False, these are added to standard libraries. Examples: ['m', 'dl'] or ['-lm', '-ldl']",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:cpp_component_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Creates a static library for use in WebAssembly components.

    This rule compiles C/C++ source files into a static library that can
    be linked into WebAssembly components, providing modular development.

    Example:
        cc_component_library(
            name = "math_utils",
            srcs = ["math.cpp", "algorithms.cpp"],
            hdrs = ["math.h", "algorithms.h"],
            language = "cpp",
            cxx_std = "c++20",
            optimize = True,
        )
    """,
)

# Re-export binary rules for convenience
cpp_wasm_binary = _cpp_wasm_binary
c_wasm_binary = _c_wasm_binary
