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

"""JCO WebAssembly optimization rule.

Optimizes WebAssembly components using wasm-opt via jco.
"""

def _jco_opt_impl(ctx):
    """Optimize a WebAssembly component using jco opt.

    Applies Binaryen wasm-opt optimizations to reduce component size
    and improve performance.

    Args:
        ctx: Rule context with component and optimization options.

    Returns:
        List of providers:
        - DefaultInfo: Optimized component file
        - OutputGroupInfo: Organized outputs (optimized group)
    """
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    jco = jco_toolchain.jco

    component = ctx.file.component
    output_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    args = ctx.actions.args()
    args.add("opt")
    args.add(component)
    args.add("-o", output_wasm)

    # Optimization level maps to wasm-opt -O flags
    if ctx.attr.optimization:
        args.add("-O" + ctx.attr.optimization)

    ctx.actions.run(
        executable = jco,
        arguments = [args],
        inputs = [component],
        outputs = [output_wasm],
        mnemonic = "JCOOptimize",
        progress_message = "Optimizing component %s with jco" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([output_wasm])),
        OutputGroupInfo(optimized = depset([output_wasm])),
    ]

jco_opt = rule(
    implementation = _jco_opt_impl,
    attrs = {
        "component": attr.label(
            doc = "WebAssembly component to optimize",
            mandatory = True,
            allow_single_file = [".wasm"],
        ),
        "optimization": attr.string(
            doc = "Optimization level: 1, 2, 3, s (size), z (minimal size)",
            default = "2",
            values = ["1", "2", "3", "s", "z"],
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
    doc = """Optimize a WebAssembly component using Binaryen via jco.

Reduces component size and improves performance through dead code
elimination, function inlining, and other wasm-opt passes.

Optimization levels:
- 1: Basic optimizations
- 2: Standard optimizations (default)
- 3: Aggressive optimizations
- s: Optimize for size
- z: Optimize for minimal size

Example:
    js_component(
        name = "service",
        srcs = ["service.js"],
        wit = "//wit:service",
        world = "service",
    )

    jco_opt(
        name = "service_optimized",
        component = ":service",
        optimization = "s",  # Size optimization for production
    )
""",
)
