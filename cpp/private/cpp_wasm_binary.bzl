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

"""C/C++ WebAssembly binary rules for WASI CLI executables.

Builds C/C++ code as WebAssembly CLI binaries that export the wasi:cli/command
interface, suitable for execution with wasmtime. No WIT interface definition
required - just compile C/C++ to a runnable WASM binary.

Example usage:

    cpp_wasm_binary(
        name = "hello",
        srcs = ["main.cpp"],
        language = "cpp",
    )

    # Run with: wasmtime run bazel-bin/examples/hello.wasm
"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//providers:providers.bzl", "WasmComponentInfo")
load("//rust:transitions.bzl", "wasm_transition")
load("//tools/bazel_helpers:file_ops_actions.bzl", "setup_cpp_workspace_action")

def _cpp_wasm_binary_impl(ctx):
    """Implementation of cpp_wasm_binary rule for C/C++ WASI CLI binaries.

    Compiles C/C++ source code into a WebAssembly WASI CLI binary using WASI SDK.
    No WIT interface required - produces a standalone executable.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: C/C++ source files to compile
            - ctx.files.hdrs: Header files
            - ctx.attr.deps: Dependencies (cc_component_library targets)
            - ctx.attr.language: Either "c" or "cpp"
            - ctx.attr.cxx_std: C++ standard (c++17/20/23)
            - ctx.attr.optimize: Enable optimizations

    Returns:
        List of providers:
        - WasmComponentInfo: Binary metadata
        - DefaultInfo: WASM binary file
    """

    # Get C/C++ toolchain
    cpp_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:cpp_component_toolchain_type"]

    clang = cpp_toolchain.clang
    wasm_tools = cpp_toolchain.wasm_tools
    sysroot = cpp_toolchain.sysroot
    sysroot_files = cpp_toolchain.sysroot_files

    # Output file
    wasm_binary = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input files
    sources = ctx.files.srcs
    headers = ctx.files.hdrs

    # Detect if we need C++ compilation support
    has_cpp_sources = any([src.extension in ["cpp", "cc", "cxx", "C", "CPP"] for src in sources])
    needs_cpp_compilation = ctx.attr.language == "cpp" or has_cpp_sources

    # Collect dependency headers and libraries
    dep_headers = []
    dep_libraries = []
    dep_includes = []

    for dep in ctx.attr.deps:
        if DefaultInfo in dep:
            for file in dep[DefaultInfo].files.to_list():
                if file.extension in ["h", "hpp", "hh", "hxx"]:
                    dep_headers.append(file)
                elif file.extension == "a":
                    dep_libraries.append(file)

        if CcInfo in dep:
            cc_info = dep[CcInfo]
            dep_includes.extend(cc_info.compilation_context.includes.to_list())
            dep_includes.extend(cc_info.compilation_context.system_includes.to_list())
            dep_includes.extend(cc_info.compilation_context.quote_includes.to_list())

            for hdr in cc_info.compilation_context.headers.to_list():
                if hdr.extension in ["h", "hpp", "hh", "hxx"]:
                    if "external/" not in hdr.path:
                        dep_headers.append(hdr)

    # Create working directory for compilation
    work_dir = setup_cpp_workspace_action(
        ctx,
        sources = sources,
        headers = headers,
        dep_headers = dep_headers,
    )

    # Build compile arguments
    compile_args = ctx.actions.args()

    # Basic compiler flags for WASI Preview 2
    compile_args.add("--target=wasm32-wasip2")
    compile_args.add("-mexec-model=command")  # CLI executable with main()

    # Resolve sysroot path
    if sysroot_files and sysroot_files.files:
        toolchain_file = sysroot_files.files.to_list()[0]
        if "/sysroot/" in toolchain_file.path:
            sysroot_base = toolchain_file.path.split("/sysroot/")[0] + "/sysroot"
            sysroot_path = sysroot_base
        else:
            sysroot_path = sysroot
    else:
        sysroot_path = sysroot

    compile_args.add("--sysroot=" + sysroot_path)

    # WASI emulation defines
    compile_args.add("-D_WASI_EMULATED_PROCESS_CLOCKS")
    compile_args.add("-D_WASI_EMULATED_SIGNAL")
    compile_args.add("-D_WASI_EMULATED_MMAN")

    # Optimization settings
    if ctx.attr.optimize:
        compile_args.add("-O3")
        compile_args.add("-flto")
    else:
        compile_args.add("-O0")
        compile_args.add("-g")

    # C++ specific flags
    if needs_cpp_compilation:
        if ctx.attr.enable_exceptions:
            compile_args.add("-fexceptions")
            compile_args.add("-fcxx-exceptions")
        else:
            compile_args.add("-fno-exceptions")

        if not ctx.attr.enable_rtti:
            compile_args.add("-fno-rtti")

        if ctx.attr.cxx_std:
            compile_args.add("-std=" + ctx.attr.cxx_std)

    # Include directories
    compile_args.add("-I" + work_dir.path)

    # Add C++ standard library paths
    if needs_cpp_compilation:
        if "/external/" in sysroot_path:
            toolchain_repo = sysroot_path.split("/sysroot")[0]
            wasi_sysroot = toolchain_repo + "/share/wasi-sysroot"
        else:
            wasi_sysroot = sysroot_path
        compile_args.add("-I" + wasi_sysroot + "/include/wasm32-wasip2/c++/v1")
        compile_args.add("-I" + wasi_sysroot + "/include/c++/v1")

        if "/external/" in sysroot_path:
            compile_args.add("-I" + toolchain_repo + "/lib/clang/20/include")

    for include in ctx.attr.includes:
        compile_args.add("-I" + include)

    # Add dependency include directories
    for include_dir in dep_includes:
        if include_dir not in [work_dir.path] + ctx.attr.includes:
            compile_args.add("-I" + include_dir)

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

    # Add source files from work directory
    for src in sources:
        compile_args.add(work_dir.path + "/" + src.basename)

    # Library linking
    if needs_cpp_compilation:
        compile_args.add("-lc++")
        compile_args.add("-lc++abi")

    for lib in ctx.attr.libs:
        if lib.startswith("-"):
            compile_args.add(lib)
        else:
            compile_args.add("-l" + lib)

    # Add dependency libraries
    for lib in dep_libraries:
        compile_args.add(lib.path)

    # Collect external headers for inputs
    external_headers = []
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            external_headers.extend(cc_info.compilation_context.headers.to_list())

    ctx.actions.run(
        executable = clang,
        arguments = [compile_args],
        inputs = [work_dir] + sysroot_files.files.to_list() + dep_libraries + dep_headers + external_headers,
        outputs = [wasm_binary],
        mnemonic = "Compile" + ("C" if ctx.attr.language == "c" else "Cpp") + "WasmBinary",
        progress_message = "Compiling %s to WASM binary for %s" % (ctx.attr.language.upper(), ctx.label),
    )

    # Create component info for consistency with other rules
    component_info = WasmComponentInfo(
        wasm_file = wasm_binary,
        wit_info = None,
        component_type = "command",  # WASI CLI command
        imports = ["wasi:cli/command"],
        exports = [],
        metadata = {
            "name": ctx.label.name,
            "language": ctx.attr.language,
            "target": "wasm32-wasip2",
            "exec_model": "command",
            "wasi_sdk": True,
            "toolchain": "wasi-sdk",
            "cxx_std": ctx.attr.cxx_std if ctx.attr.cxx_std else None,
            "optimization": ctx.attr.optimize,
        },
        profile = "release" if ctx.attr.optimize else "debug",
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(
            files = depset([wasm_binary]),
            executable = wasm_binary,
        ),
    ]

cpp_wasm_binary = rule(
    implementation = _cpp_wasm_binary_impl,
    cfg = wasm_transition,
    executable = True,
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
        "enable_rtti": attr.bool(
            default = False,
            doc = "Enable C++ RTTI",
        ),
        "enable_exceptions": attr.bool(
            default = False,
            doc = "Enable C++ exceptions",
        ),
        "libs": attr.string_list(
            default = [],
            doc = "Additional libraries to link",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:cpp_component_toolchain_type",
        "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    ],
    doc = """
    Builds a WebAssembly CLI binary from C/C++ source code.

    This rule compiles C/C++ code to a WASI Preview 2 CLI binary that can be
    executed with wasmtime. No WIT interface definition required - produces
    a standalone executable.

    Example:
        cpp_wasm_binary(
            name = "hello",
            srcs = ["main.cpp"],
            language = "cpp",
            cxx_std = "c++20",
            optimize = True,
        )

        # Run with: wasmtime run bazel-bin/path/to/hello.wasm
    """,
)

def c_wasm_binary(
        name,
        srcs,
        hdrs = [],
        deps = [],
        includes = [],
        defines = [],
        copts = [],
        optimize = True,
        libs = [],
        **kwargs):
    """Convenience wrapper for cpp_wasm_binary with language="c".

    Args:
        name: Target name
        srcs: C source files
        hdrs: C header files
        deps: Dependencies
        includes: Additional include directories
        defines: Preprocessor definitions
        copts: Additional compiler options
        optimize: Enable optimizations
        libs: Additional libraries to link
        **kwargs: Additional arguments passed to cpp_wasm_binary
    """
    cpp_wasm_binary(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        language = "c",
        includes = includes,
        defines = defines,
        copts = copts,
        optimize = optimize,
        libs = libs,
        **kwargs
    )
