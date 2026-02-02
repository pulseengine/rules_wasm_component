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

"""JCO TypeScript type generation rule.

Generates TypeScript type definitions from WebAssembly components using jco.
"""

def _jco_types_impl(ctx):
    """Generate TypeScript type definitions from a WebAssembly component.

    Uses jco to extract the component's WIT interface and generate
    TypeScript definitions for type-safe consumption.

    Args:
        ctx: Rule context with component input and generation options.

    Returns:
        List of providers:
        - DefaultInfo: Generated types directory
        - OutputGroupInfo: Organized outputs (types group)
    """
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    jco = jco_toolchain.jco

    component = ctx.file.component
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_types")

    args = ctx.actions.args()
    args.add("types")
    args.add(component)
    args.add("-o", output_dir.path)

    if ctx.attr.world_name:
        args.add("--world-name", ctx.attr.world_name)

    if ctx.attr.name_override:
        args.add("--name", ctx.attr.name_override)

    ctx.actions.run(
        executable = jco,
        arguments = [args],
        inputs = [component],
        outputs = [output_dir],
        mnemonic = "JCOTypes",
        progress_message = "Generating TypeScript types from %s" % ctx.label,
    )

    return [
        DefaultInfo(files = depset([output_dir])),
        OutputGroupInfo(types = depset([output_dir])),
    ]

jco_types = rule(
    implementation = _jco_types_impl,
    attrs = {
        "component": attr.label(
            doc = "WebAssembly component to generate types from",
            mandatory = True,
            allow_single_file = [".wasm"],
        ),
        "world_name": attr.string(
            doc = "Override world name in generated types",
        ),
        "name_override": attr.string(
            doc = "Override component name in generated types",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
    doc = """Generate TypeScript type definitions from a WebAssembly component.

Extracts the WIT interface from a compiled component and generates
TypeScript definitions for type-safe consumption in JavaScript/TypeScript
projects.

Example:
    js_component(
        name = "calculator",
        srcs = ["calculator.js"],
        wit = "//wit:calculator",
        world = "calculator",
    )

    jco_types(
        name = "calculator_types",
        component = ":calculator",
    )

    # Output: calculator_types/
    #   ├── calculator.d.ts
    #   └── interfaces/
    #       └── ...
""",
)
