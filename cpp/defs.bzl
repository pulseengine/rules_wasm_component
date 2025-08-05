"""Bazel rules for C/C++ WebAssembly components with Preview2 support"""

load("//providers:providers.bzl", "WasmComponentInfo")
load("//rust:transitions.bzl", "wasm_transition")

def _cpp_component_impl(ctx):
    """Implementation of cpp_component rule"""

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]
    clang = cpp_toolchain.clang if ctx.attr.language == "c" else cpp_toolchain.clang_cpp
    wit_bindgen = cpp_toolchain.wit_bindgen
    wasm_tools = cpp_toolchain.wasm_tools
    sysroot = cpp_toolchain.sysroot

    # Output files
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input files
    sources = ctx.files.srcs
    headers = ctx.files.hdrs
    wit_file = ctx.file.wit

    # Collect dependency headers
    dep_headers = []
    dep_libraries = []
    for dep in ctx.attr.deps:
        if DefaultInfo in dep:
            for file in dep[DefaultInfo].files.to_list():
                if file.extension in ["h", "hpp", "hh", "hxx"]:
                    dep_headers.append(file)
                elif file.extension == "a":
                    dep_libraries.append(file)

    # Generate bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate C/C++ bindings from WIT
    wit_args = ctx.actions.args()
    wit_args.add("c")
    wit_args.add("--out-dir", bindings_dir.path)

    if ctx.attr.world:
        wit_args.add("--world", ctx.attr.world)

    wit_args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen,
        arguments = [wit_args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = "WitBindgenCpp",
        progress_message = "Generating C/C++ bindings for %s" % ctx.label,
    )

    # Create working directory for compilation
    work_dir = ctx.actions.declare_directory(ctx.attr.name + "_work")

    # Prepare sources and headers
    prep_script = ctx.actions.declare_file(ctx.attr.name + "_prep.sh")
    prep_content = """#!/bin/bash
set -e

WORK_DIR="{work_dir}"
BINDINGS_DIR="{bindings_dir}"

# Create working directory structure
mkdir -p "$WORK_DIR"

# Copy source files
{copy_sources}

# Copy header files
{copy_headers}

# Copy dependency headers
{copy_dep_headers}

# Copy generated bindings
if [ -d "$BINDINGS_DIR" ]; then
    cp -r "$BINDINGS_DIR"/* "$WORK_DIR/"
fi

echo "Prepared C/C++ component sources in $WORK_DIR"
""".format(
        work_dir = work_dir.path,
        bindings_dir = bindings_dir.path,
        copy_sources = "\n".join([
            'cp "{}" "$WORK_DIR/{}"'.format(src.path, src.basename)
            for src in sources
        ]),
        copy_headers = "\n".join([
            'cp "{}" "$WORK_DIR/{}"'.format(hdr.path, hdr.basename)
            for hdr in headers
        ]),
        copy_dep_headers = "\n".join([
            'cp "{}" "$WORK_DIR/{}"'.format(hdr.path, hdr.basename)
            for hdr in dep_headers
        ]),
    )

    ctx.actions.write(
        output = prep_script,
        content = prep_content,
        is_executable = True,
    )

    # Run preparation
    ctx.actions.run(
        executable = prep_script,
        inputs = [bindings_dir] + sources + headers + dep_headers + dep_libraries,
        outputs = [work_dir],
        mnemonic = "PrepareCppComponent",
        progress_message = "Preparing C/C++ component sources for %s" % ctx.label,
    )

    # Compile to WASM
    wasm_binary = ctx.actions.declare_file(ctx.attr.name + "_module.wasm")

    compile_args = ctx.actions.args()

    # Basic compiler flags for Preview2
    compile_args.add("--target=wasm32-wasip2")
    compile_args.add("--sysroot=" + sysroot.path)

    # Component model definitions
    compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
    compile_args.add("-D_WASI_EMULATED_SIGNAL")
    compile_args.add("-D_WASI_EMULATED_MMAN")
    compile_args.add("-DCOMPONENT_MODEL_PREVIEW2")

    # Optimization and language settings
    if ctx.attr.optimize:
        compile_args.add("-O3")
        compile_args.add("-flto")
    else:
        compile_args.add("-O0")
        compile_args.add("-g")

    # C++ specific flags
    if ctx.attr.language == "cpp":
        if ctx.attr.enable_exceptions:
            # Enable exceptions if specifically requested
            pass
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
    for include in ctx.attr.includes:
        compile_args.add("-I" + include)
    
    # Add dependency header directories
    for dep_hdr in dep_headers:
        include_dir = dep_hdr.dirname
        if include_dir not in [work_dir.path] + ctx.attr.includes:
            compile_args.add("-I" + include_dir)

    # Defines
    for define in ctx.attr.defines:
        compile_args.add("-D" + define)

    # Compile flags
    for flag in ctx.attr.copts:
        compile_args.add(flag)

    # Output
    compile_args.add("-o", wasm_binary.path)

    # Add source files from work directory
    for src in sources:
        compile_args.add(work_dir.path + "/" + src.basename)

    ctx.actions.run(
        executable = clang,
        arguments = [compile_args],
        inputs = [work_dir, sysroot],
        outputs = [wasm_binary],
        mnemonic = "CompileCppWasm",
        progress_message = "Compiling C/C++ to WASM for %s" % ctx.label,
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
        mnemonic = "CreateCppComponent",
        progress_message = "Creating WebAssembly component for %s" % ctx.label,
    )

    # Create component info
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = wit_file,
            package_name = ctx.attr.package_name or "{}:component@1.0.0".format(ctx.attr.name),
        ),
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm])),
        OutputGroupInfo(
            bindings = depset([bindings_dir]),
            wasm_module = depset([wasm_binary]),
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
    },
    toolchains = ["@rules_wasm_component//toolchains:cpp_component_toolchain_type"],
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
    """Implementation of cpp_wit_bindgen rule"""

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]
    wit_bindgen = cpp_toolchain.wit_bindgen

    # Input WIT file
    wit_file = ctx.file.wit

    # Output bindings directory
    bindings_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Generate C/C++ bindings
    args = ctx.actions.args()
    args.add("c")
    args.add("--out-dir", bindings_dir.path)

    if ctx.attr.world:
        args.add("--world", ctx.attr.world)

    if ctx.attr.stubs_only:
        args.add("--stubs-only")

    if ctx.attr.string_encoding:
        args.add("--string-encoding", ctx.attr.string_encoding)

    args.add(wit_file.path)

    ctx.actions.run(
        executable = wit_bindgen,
        arguments = [args],
        inputs = [wit_file],
        outputs = [bindings_dir],
        mnemonic = "CppWitBindgen",
        progress_message = "Generating C/C++ WIT bindings for %s" % ctx.label,
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
    },
    toolchains = ["@rules_wasm_component//toolchains:cpp_component_toolchain_type"],
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
    """Implementation of cc_component_library rule"""

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]
    clang = cpp_toolchain.clang if ctx.attr.language == "c" else cpp_toolchain.clang_cpp
    llvm_ar = cpp_toolchain.llvm_ar
    sysroot = cpp_toolchain.sysroot

    # Output library
    library = ctx.actions.declare_file("lib{}.a".format(ctx.attr.name))

    # Collect dependency headers
    dep_headers = []
    for dep in ctx.attr.deps:
        if DefaultInfo in dep:
            for file in dep[DefaultInfo].files.to_list():
                if file.extension in ["h", "hpp", "hh", "hxx"]:
                    dep_headers.append(file)

    # Compile source files to object files
    object_files = []

    for src in ctx.files.srcs:
        obj_file = ctx.actions.declare_file(src.basename.rsplit(".", 1)[0] + ".o")
        object_files.append(obj_file)

        # Compile arguments
        compile_args = ctx.actions.args()
        compile_args.add("--target=wasm32-wasip2")
        compile_args.add("--sysroot=" + sysroot.path)
        compile_args.add("-c")  # Compile only, don't link

        # Component model definitions
        compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
        compile_args.add("-D_WASI_EMULATED_SIGNAL")
        compile_args.add("-D_WASI_EMULATED_MMAN")
        compile_args.add("-DCOMPONENT_MODEL_PREVIEW2")

        # Optimization
        if ctx.attr.optimize:
            compile_args.add("-O3")
        else:
            compile_args.add("-O0")
            compile_args.add("-g")

        # C++ specific flags
        if ctx.attr.language == "cpp":
            if ctx.attr.enable_exceptions:
                # Enable exceptions if specifically requested
                pass
            else:
                compile_args.add("-fno-exceptions")
            
            compile_args.add("-fno-rtti")
            if ctx.attr.cxx_std:
                compile_args.add("-std=" + ctx.attr.cxx_std)

        # Include directories
        for hdr in ctx.files.hdrs:
            compile_args.add("-I" + hdr.dirname)
        for include in ctx.attr.includes:
            compile_args.add("-I" + include)

        # Add dependency header directories
        for dep_hdr in dep_headers:
            compile_args.add("-I" + dep_hdr.dirname)

        # Defines
        for define in ctx.attr.defines:
            compile_args.add("-D" + define)

        # Compiler options
        for opt in ctx.attr.copts:
            compile_args.add(opt)

        # Output and input
        compile_args.add("-o", obj_file.path)
        compile_args.add(src.path)

        ctx.actions.run(
            executable = clang,
            arguments = [compile_args],
            inputs = [src, sysroot] + ctx.files.hdrs + dep_headers,
            outputs = [obj_file],
            mnemonic = "CompileCppObject",
            progress_message = "Compiling {} for component library".format(src.basename),
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
        mnemonic = "CreateCppLibrary",
        progress_message = "Creating component library %s" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([library] + ctx.files.hdrs)),
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
    },
    toolchains = ["@rules_wasm_component//toolchains:cpp_component_toolchain_type"],
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
