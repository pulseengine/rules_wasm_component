"""Wasmtime AOT precompilation rule for WebAssembly components"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmPrecompiledInfo")

def _wasm_precompile_impl(ctx):
    """Implementation of wasm_precompile rule"""

    # Get input WASM file
    if ctx.file.wasm_file:
        input_wasm = ctx.file.wasm_file
        source_info = None
    elif ctx.attr.component:
        component_info = ctx.attr.component[WasmComponentInfo]
        input_wasm = component_info.wasm_file
        source_info = component_info
    else:
        fail("Either wasm_file or component must be specified")

    # Get Wasmtime toolchain
    wasmtime_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime

    # Output precompiled file
    cwasm_file = ctx.actions.declare_file(ctx.label.name + ".cwasm")

    # Build compilation arguments
    args = ctx.actions.args()
    args.add("compile")

    # Optimization level
    args.add("-O")
    args.add("opt-level={}".format(ctx.attr.optimization_level))

    # Debug info control (DWARF debug information including symbols)
    if ctx.attr.debug_info:
        args.add("-D")
        args.add("debug-info")
    else:
        # Default: disable debug info for production builds (87% size reduction)
        args.add("-D")
        args.add("debug-info=n")

    # Target specification (for cross-compilation)
    if ctx.attr.target_triple:
        args.add("--target")
        args.add(ctx.attr.target_triple)

    # Add input and output
    args.add(input_wasm)
    args.add("-o")
    args.add(cwasm_file)

    # Create version info for cache key stability
    wasmtime_version = ctx.attr._wasmtime_version
    target_arch = ctx.attr.target_triple or "host"

    # Run Wasmtime compilation
    ctx.actions.run(
        executable = wasmtime,
        arguments = [args],
        inputs = [input_wasm],
        outputs = [cwasm_file],
        mnemonic = "WasmAOTCompile",
        progress_message = "AOT compiling WASM component {} for {} (wasmtime v{}){}".format(
            input_wasm.short_path,
            target_arch,
            wasmtime_version,
            " [with debug info]" if ctx.attr.debug_info else " [production]",
        ),
        use_default_shell_env = False,
        # Cache key includes wasmtime version and compilation settings
        execution_requirements = {
            "supports-workers": "0",  # Disable workers for deterministic builds
        },
    )

    # Create compatibility hash for cache validation
    # This ensures different wasmtime versions/settings create different cache entries
    compatibility_factors = [
        wasmtime_version,
        target_arch,
        ctx.attr.optimization_level,
        str(ctx.attr.debug_info),
    ]
    compatibility_hash = hash("_".join(compatibility_factors))

    # Return providers
    precompiled_info = WasmPrecompiledInfo(
        cwasm_file = cwasm_file,
        source_wasm = input_wasm,
        wasmtime_version = wasmtime_version,
        target_arch = target_arch,
        optimization_level = ctx.attr.optimization_level,
        compilation_flags = [
            "opt-level={}".format(ctx.attr.optimization_level),
        ] + (["debug-info"] if ctx.attr.debug_info else ["no-debug-info"]),
        compatibility_hash = str(compatibility_hash),
    )

    providers = [
        DefaultInfo(
            files = depset([cwasm_file]),
            runfiles = ctx.runfiles(files = [cwasm_file]),
        ),
        precompiled_info,
        OutputGroupInfo(
            cwasm = depset([cwasm_file]),
        ),
    ]

    # If this was built from a component, also provide the original component info
    if source_info:
        providers.append(source_info)

    return providers

wasm_precompile = rule(
    implementation = _wasm_precompile_impl,
    attrs = {
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "Input WebAssembly module/component to precompile",
        ),
        "component": attr.label(
            providers = [WasmComponentInfo],
            doc = "Alternative: WasmComponent target to precompile",
        ),
        "optimization_level": attr.string(
            default = "2",
            values = ["0", "1", "2", "s"],
            doc = "Optimization level (0=none, 1=speed, 2=speed+size, s=size)",
        ),
        "debug_info": attr.bool(
            default = False,
            doc = "Include DWARF debug information (increases .cwasm size ~8x)",
        ),
        "target_triple": attr.string(
            doc = "Target triple for cross-compilation (e.g., x86_64-unknown-linux-gnu)",
        ),
        "_wasmtime_version": attr.string(
            default = "35.0.0",  # Should match toolchain version
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
    doc = """
    Ahead-of-Time (AOT) compile WebAssembly modules using Wasmtime.

    This rule precompiles WASM modules into native machine code (.cwasm files)
    for faster startup times. The output is cached by Bazel based on:
    - Source WASM content
    - Wasmtime version
    - Compilation settings
    - Target architecture

    Debug information: By default, debug info is excluded for production
    builds (87% size reduction). Set debug_info=True for debugging.

    Examples:
        # Production build (small, no debug info) - Default
        wasm_precompile(
            name = "my_component_aot",
            component = ":my_component",
            optimization_level = "2",
        )

        # Debug build (large, with debug info and symbols)
        wasm_precompile(
            name = "my_component_debug",
            component = ":my_component",
            debug_info = True,
        )
    """,
)

def _wasm_precompile_multi_impl(ctx):
    """Implementation of wasm_precompile_multi rule for multiple target architectures"""

    # Get input component
    if ctx.attr.component:
        component_info = ctx.attr.component[WasmComponentInfo]
        input_wasm = component_info.wasm_file
        source_info = component_info
    else:
        fail("component must be specified for multi-target compilation")

    # Get Wasmtime toolchain
    wasmtime_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime
    wasmtime_version = ctx.attr._wasmtime_version

    # Output files for each target
    output_files = []
    precompiled_infos = []

    for target_name, target_triple in ctx.attr.targets.items():
        # Output precompiled file with target suffix
        cwasm_file = ctx.actions.declare_file("{}.{}.cwasm".format(ctx.label.name, target_name))

        # Build compilation arguments
        args = ctx.actions.args()
        args.add("compile")

        # Optimization level
        args.add("-O")
        args.add("opt-level={}".format(ctx.attr.optimization_level))

        # Debug info control
        if ctx.attr.debug_info:
            args.add("-D")
            args.add("debug-info")

        # Target specification
        args.add("--target")
        args.add(target_triple)

        # Add input and output
        args.add(input_wasm)
        args.add("-o")
        args.add(cwasm_file)

        # Run Wasmtime compilation for this target
        ctx.actions.run(
            executable = wasmtime,
            arguments = [args],
            inputs = [input_wasm],
            outputs = [cwasm_file],
            mnemonic = "WasmAOTCompileMulti",
            progress_message = "AOT compiling WASM component {} for {} (wasmtime v{})".format(
                input_wasm.short_path,
                target_triple,
                wasmtime_version,
            ),
            use_default_shell_env = False,
            execution_requirements = {
                "supports-workers": "0",  # Disable workers for deterministic builds
            },
        )

        # Create compatibility hash for this target
        compatibility_factors = [
            wasmtime_version,
            target_triple,
            ctx.attr.optimization_level,
            str(ctx.attr.debug_info),
            str(ctx.attr.strip_symbols),
        ]
        compatibility_hash = hash("_".join(compatibility_factors))

        # Create precompiled info for this target
        precompiled_info = WasmPrecompiledInfo(
            cwasm_file = cwasm_file,
            source_wasm = input_wasm,
            wasmtime_version = wasmtime_version,
            target_arch = target_triple,
            optimization_level = ctx.attr.optimization_level,
            compilation_flags = [
                "opt-level={}".format(ctx.attr.optimization_level),
            ] + (["debug-info"] if ctx.attr.debug_info else []),
            compatibility_hash = str(compatibility_hash),
        )

        output_files.append(cwasm_file)
        precompiled_infos.append(precompiled_info)

    # Create output groups for each target
    output_groups = {}
    for i, (target_name, _) in enumerate(ctx.attr.targets.items()):
        output_groups[target_name] = depset([output_files[i]])

    # Add combined group
    output_groups["all"] = depset(output_files)

    providers = [
        DefaultInfo(
            files = depset(output_files),
            runfiles = ctx.runfiles(files = output_files),
        ),
        OutputGroupInfo(**output_groups),
    ]

    # Add component info if available
    if source_info:
        providers.append(source_info)

    return providers

wasm_precompile_multi = rule(
    implementation = _wasm_precompile_multi_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "WasmComponent target to precompile for multiple architectures",
        ),
        "targets": attr.string_dict(
            mandatory = True,
            doc = "Dictionary mapping target names to target triples (e.g., {'linux_x64': 'x86_64-unknown-linux-gnu'})",
        ),
        "optimization_level": attr.string(
            default = "2",
            values = ["0", "1", "2", "s"],
            doc = "Optimization level (0=none, 1=speed, 2=speed+size, s=size)",
        ),
        "debug_info": attr.bool(
            default = False,
            doc = "Include debug information (increases .cwasm size significantly)",
        ),
        "strip_symbols": attr.bool(
            default = True,
            doc = "Strip symbol tables to reduce size (saves ~25%)",
        ),
        "_wasmtime_version": attr.string(
            default = "35.0.0",  # Should match toolchain version
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
    doc = """
    Ahead-of-Time (AOT) compile WebAssembly modules for multiple target architectures using Wasmtime.

    This rule precompiles WASM modules into native machine code (.cwasm files) for multiple
    architectures in parallel, enabling efficient multi-platform deployment.

    Example:
        wasm_precompile_multi(
            name = "my_component_multi_arch",
            component = ":my_component",
            targets = {
                "linux_x64": "x86_64-unknown-linux-gnu",
                "linux_arm64": "aarch64-unknown-linux-gnu",
                "pulley64": "pulley64",  # Portable
            },
            optimization_level = "2",
        )

    Output files:
        - my_component_multi_arch.linux_x64.cwasm
        - my_component_multi_arch.linux_arm64.cwasm
        - my_component_multi_arch.pulley64.cwasm

    Access individual targets:
        bazel build :my_component_multi_arch:linux_x64
        bazel build :my_component_multi_arch:all
    """,
)
