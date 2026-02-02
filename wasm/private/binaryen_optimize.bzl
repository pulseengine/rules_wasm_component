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

"""Binaryen wasm-opt optimization rule.

Provides the binaryen_optimize rule for optimizing WebAssembly components
using Binaryen's wasm-opt tool. This performs binary-level optimizations
including dead code elimination, function inlining, and size reduction.
"""

def _binaryen_optimize_impl(ctx):
    """Implementation of binaryen_optimize rule."""
    input_wasm = ctx.file.component
    output_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Get binaryen toolchain
    binaryen_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:binaryen_toolchain_type"]
    wasm_opt = binaryen_toolchain.wasm_opt

    # Build command arguments
    args = ctx.actions.args()

    # Optimization level
    if ctx.attr.optimization:
        args.add("-O" + ctx.attr.optimization)

    # Additional flags
    if ctx.attr.shrink_level:
        args.add("-s")

    if ctx.attr.debug_info:
        args.add("-g")

    # Input and output
    args.add(input_wasm)
    args.add("-o", output_wasm)

    ctx.actions.run(
        inputs = [input_wasm],
        outputs = [output_wasm],
        executable = wasm_opt,
        arguments = [args],
        mnemonic = "BinaryenOptimize",
        progress_message = "Optimizing WebAssembly with Binaryen: %{label}",
    )

    return [
        DefaultInfo(files = depset([output_wasm])),
        OutputGroupInfo(optimized = depset([output_wasm])),
    ]

binaryen_optimize = rule(
    implementation = _binaryen_optimize_impl,
    attrs = {
        "component": attr.label(
            doc = "The WebAssembly component or module to optimize",
            mandatory = True,
            allow_single_file = [".wasm"],
        ),
        "optimization": attr.string(
            doc = "Optimization level: 1, 2, 3, 4, s (size), z (minimal size)",
            default = "2",
            values = ["1", "2", "3", "4", "s", "z"],
        ),
        "shrink_level": attr.bool(
            doc = "Enable extra size shrinking passes",
            default = False,
        ),
        "debug_info": attr.bool(
            doc = "Preserve debug information",
            default = False,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:binaryen_toolchain_type"],
    doc = """Optimize a WebAssembly component using Binaryen wasm-opt.

Performs binary-level optimizations to reduce size and improve performance:
- Dead code elimination
- Function inlining
- Constant folding
- Local optimization
- Vacuum (remove unreachable code)

Optimization levels:
- 1: Basic optimizations (-O1)
- 2: Standard optimizations (-O2, default)
- 3: Aggressive optimizations (-O3)
- 4: Maximum optimizations (-O4)
- s: Optimize for size (-Os)
- z: Optimize for minimal size (-Oz)

This rule complements wasm_optimize (LOOM) which performs expression-level
optimizations with formal verification. Both can be chained for maximum
optimization.

Example:
    rust_wasm_component(
        name = "my_component",
        ...
    )

    # Binary-level optimization with Binaryen
    binaryen_optimize(
        name = "my_component_binaryen",
        component = ":my_component",
        optimization = "s",  # Size optimization
    )

    # Chain with LOOM for additional optimization
    wasm_optimize(
        name = "my_component_optimized",
        component = ":my_component_binaryen",
        verify = True,
    )
""",
)
