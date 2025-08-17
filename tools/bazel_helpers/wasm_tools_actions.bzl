"""Universal WASM Tools operations actions for Bazel rules

This module provides helper functions that replace direct wasm-tools calls
with the WASM Tools Integration Component for consistent, cross-platform operations.

Usage:
    load("//tools/bazel_helpers:wasm_tools_actions.bzl", "wasm_tools_action", "validate_wasm_action")

    # In your rule implementation:
    wasm_tools_action(ctx, "validate", wasm_file=input_wasm, features=["component-model"])
    component_file = wasm_tools_action(ctx, "component-embed", wit_file=wit, wasm_module=module)
"""

def wasm_tools_action(ctx, operation, **kwargs):
    """Execute a wasm-tools operation using the WASM Tools Integration Component

    Args:
        ctx: Bazel rule context
        operation: Operation to perform (validate, component-new, component-embed, etc.)
        **kwargs: Operation-specific arguments

    Returns:
        Output file or validation result
    """

    # Get the WASM tools component from toolchain
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools_component_target = wasm_tools_toolchain.wasm_tools

    if not wasm_tools_component_target:
        fail("WASM Tools Integration Component not available in toolchain")

    # Extract executable from target
    wasm_tools_component = wasm_tools_component_target.files_to_run

    if operation == "validate":
        return _validate_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "component-new":
        return _component_new_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "component-embed":
        return _component_embed_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "component-wit":
        return _component_wit_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "is-component":
        return _is_component_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "compose":
        return _compose_action(ctx, wasm_tools_component, **kwargs)
    elif operation == "strip":
        return _strip_action(ctx, wasm_tools_component, **kwargs)
    else:
        fail("Unsupported wasm-tools operation: {}".format(operation))

def _validate_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools validate operation"""

    wasm_file = kwargs.get("wasm_file")
    features = kwargs.get("features", [])

    if not wasm_file:
        fail("validate operation requires 'wasm_file' argument")

    # Create validation marker file
    validation_marker = ctx.actions.declare_file(ctx.label.name + "_validation.marker")

    # Build arguments
    args = ["validate", wasm_file.path]
    for feature in features:
        args.extend(["--features", feature])

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = args,
        inputs = [wasm_file],
        outputs = [validation_marker],
        mnemonic = "WasmValidate",
        progress_message = "Validating WASM file {} for {}".format(wasm_file.short_path, ctx.label),
    )

    return validation_marker

def _component_new_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools component new operation"""

    wasm_module = kwargs.get("wasm_module")
    output_name = kwargs.get("output_name", ctx.label.name + ".wasm")
    adapter = kwargs.get("adapter")
    options = kwargs.get("options", [])

    if not wasm_module:
        fail("component-new operation requires 'wasm_module' argument")

    # Create output component file
    component_file = ctx.actions.declare_file(output_name)

    # Create configuration for the component
    config = {
        "input_module": wasm_module.path,
        "output_path": component_file.path,
        "adapter": adapter.path if adapter else None,
        "options": options,
    }

    config_file = ctx.actions.declare_file(ctx.label.name + "_component_new_config.json")
    ctx.actions.write(
        output = config_file,
        content = _encode_json(config),
    )

    # Collect inputs
    inputs = [wasm_module, config_file]
    if adapter:
        inputs.append(adapter)

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["component-new", "--config", config_file.path],
        inputs = inputs,
        outputs = [component_file],
        mnemonic = "WasmComponentNew",
        progress_message = "Creating component from {} for {}".format(wasm_module.short_path, ctx.label),
    )

    return component_file

def _component_embed_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools component embed operation"""

    wit_file = kwargs.get("wit_file")
    wasm_module = kwargs.get("wasm_module")
    output_name = kwargs.get("output_name", ctx.label.name + ".wasm")
    world = kwargs.get("world")
    options = kwargs.get("options", [])

    if not wit_file or not wasm_module:
        fail("component-embed operation requires 'wit_file' and 'wasm_module' arguments")

    # Create output component file
    component_file = ctx.actions.declare_file(output_name)

    # Create configuration for the embedding
    config = {
        "wit_file": wit_file.path,
        "wasm_module": wasm_module.path,
        "output_path": component_file.path,
        "world": world,
        "options": options,
    }

    config_file = ctx.actions.declare_file(ctx.label.name + "_embed_config.json")
    ctx.actions.write(
        output = config_file,
        content = _encode_json(config),
    )

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["component-embed", "--config", config_file.path],
        inputs = [wit_file, wasm_module, config_file],
        outputs = [component_file],
        mnemonic = "WasmComponentEmbed",
        progress_message = "Embedding WIT into {} for {}".format(wasm_module.short_path, ctx.label),
    )

    return component_file

def _component_wit_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools component wit operation"""

    component_file = kwargs.get("component_file")
    output_name = kwargs.get("output_name", ctx.label.name + ".wit")

    if not component_file:
        fail("component-wit operation requires 'component_file' argument")

    wit_output = ctx.actions.declare_file(output_name)

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["component-wit", component_file.path, wit_output.path],
        inputs = [component_file],
        outputs = [wit_output],
        mnemonic = "WasmComponentWit",
        progress_message = "Extracting WIT from {} for {}".format(component_file.short_path, ctx.label),
    )

    return wit_output

def _is_component_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools is-component check"""

    wasm_file = kwargs.get("wasm_file")

    if not wasm_file:
        fail("is-component operation requires 'wasm_file' argument")

    # Create result marker file
    result_file = ctx.actions.declare_file(ctx.label.name + "_is_component.txt")

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["is-component", wasm_file.path],
        inputs = [wasm_file],
        outputs = [result_file],
        mnemonic = "WasmIsComponent",
        progress_message = "Checking if {} is component for {}".format(wasm_file.short_path, ctx.label),
    )

    return result_file

def _compose_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools compose operation"""

    components = kwargs.get("components", [])
    composition_file = kwargs.get("composition_file")
    output_name = kwargs.get("output_name", ctx.label.name + "_composed.wasm")
    options = kwargs.get("options", [])

    if not components or not composition_file:
        fail("compose operation requires 'components' and 'composition_file' arguments")

    composed_component = ctx.actions.declare_file(output_name)

    # Create configuration for composition
    config = {
        "components": [c.path for c in components],
        "composition_file": composition_file.path,
        "output_path": composed_component.path,
        "options": options,
    }

    config_file = ctx.actions.declare_file(ctx.label.name + "_compose_config.json")
    ctx.actions.write(
        output = config_file,
        content = _encode_json(config),
    )

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["compose", "--config", config_file.path],
        inputs = components + [composition_file, config_file],
        outputs = [composed_component],
        mnemonic = "WasmCompose",
        progress_message = "Composing {} components for {}".format(len(components), ctx.label),
    )

    return composed_component

def _strip_action(ctx, wasm_tools_component, **kwargs):
    """Execute wasm-tools strip operation"""

    input_file = kwargs.get("input_file")
    output_name = kwargs.get("output_name", ctx.label.name + "_stripped.wasm")

    if not input_file:
        fail("strip operation requires 'input_file' argument")

    stripped_file = ctx.actions.declare_file(output_name)

    ctx.actions.run(
        executable = wasm_tools_component,
        arguments = ["strip", input_file.path, stripped_file.path],
        inputs = [input_file],
        outputs = [stripped_file],
        mnemonic = "WasmStrip",
        progress_message = "Stripping {} for {}".format(input_file.short_path, ctx.label),
    )

    return stripped_file

# Convenience functions for common operations

def validate_wasm_action(ctx, wasm_file, features = None):
    """Validate a WASM file with optional features"""
    return wasm_tools_action(ctx, "validate", wasm_file = wasm_file, features = features or [])

def create_component_action(ctx, wasm_module, adapter = None, output_name = None):
    """Create a component from a WASM module"""
    return wasm_tools_action(
        ctx,
        "component-new",
        wasm_module = wasm_module,
        adapter = adapter,
        output_name = output_name,
    )

def embed_wit_action(ctx, wit_file, wasm_module, world = None, output_name = None):
    """Embed WIT metadata into a WASM module"""
    return wasm_tools_action(
        ctx,
        "component-embed",
        wit_file = wit_file,
        wasm_module = wasm_module,
        world = world,
        output_name = output_name,
    )

def extract_wit_action(ctx, component_file, output_name = None):
    """Extract WIT interface from a component"""
    return wasm_tools_action(
        ctx,
        "component-wit",
        component_file = component_file,
        output_name = output_name,
    )

def check_is_component_action(ctx, wasm_file):
    """Check if a WASM file is a component"""
    return wasm_tools_action(ctx, "is-component", wasm_file = wasm_file)

def compose_components_action(ctx, components, composition_file, output_name = None):
    """Compose multiple components"""
    return wasm_tools_action(
        ctx,
        "compose",
        components = components,
        composition_file = composition_file,
        output_name = output_name,
    )

def strip_component_action(ctx, input_file, output_name = None):
    """Strip debug information from a component"""
    return wasm_tools_action(
        ctx,
        "strip",
        input_file = input_file,
        output_name = output_name,
    )

def _encode_json(obj):
    """Simple JSON encoding for configuration objects"""
    if type(obj) == "dict":
        pairs = []
        for key, value in obj.items():
            if value == None:
                continue  # Skip None values
            elif type(value) == "string":
                pairs.append('"{}": "{}"'.format(key, value.replace('"', '\\"')))
            elif type(value) == "list":
                items = []
                for item in value:
                    if type(item) == "string":
                        items.append('"{}"'.format(item.replace('"', '\\"')))
                    else:
                        items.append(str(item))
                pairs.append('"{}": [{}]'.format(key, ", ".join(items)))
            elif type(value) == "bool":
                pairs.append('"{}": {}'.format(key, "true" if value else "false"))
            else:
                pairs.append('"{}": {}'.format(key, str(value)))
        return "{{{}}}".format(", ".join(pairs))
    else:
        return str(obj)
