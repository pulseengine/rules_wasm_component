# Copyright 2025 Ralf Anton Beier. All rights reserved.
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

"""Common test utilities for rules_wasm_component analysis tests.

This module provides shared utilities for writing analysis tests,
following patterns established by rules_rust. These utilities make
it easier to:
- Find and inspect actions created by rules
- Assert on command-line arguments
- Validate provider fields
- Check action inputs and outputs

Example usage:

    def _my_test_impl(ctx):
        env = analysistest.begin(ctx)
        target = analysistest.target_under_test(env)

        # Find a specific action
        rustc_action = find_action_by_mnemonic(target, "Rustc")
        asserts.true(env, rustc_action != None, "Should have Rustc action")

        # Check arguments
        assert_argv_contains(env, rustc_action, "--target=wasm32-wasip2")

        # Check provider fields
        assert_provider_field(env, target, WasmComponentInfo, "component_type", "component")

        return analysistest.end(env)
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts")

def find_action_by_mnemonic(target, mnemonic):
    """Find the first action with the given mnemonic.

    Args:
        target: The target under test (from analysistest.target_under_test)
        mnemonic: The action mnemonic to search for (e.g., "Rustc", "WitBindgen")

    Returns:
        The first matching action, or None if not found.

    Example:
        rustc_action = find_action_by_mnemonic(target, "Rustc")
        if rustc_action:
            # Inspect the action
            print(rustc_action.argv)
    """
    for action in target.actions:
        if action.mnemonic == mnemonic:
            return action
    return None

def find_all_actions_by_mnemonic(target, mnemonic):
    """Find all actions with the given mnemonic.

    Args:
        target: The target under test
        mnemonic: The action mnemonic to search for

    Returns:
        List of matching actions (may be empty).

    Example:
        compile_actions = find_all_actions_by_mnemonic(target, "CppCompile")
        asserts.equals(env, 3, len(compile_actions))
    """
    return [action for action in target.actions if action.mnemonic == mnemonic]

def get_action_mnemonics(target):
    """Get a list of all action mnemonics for a target.

    Useful for debugging and understanding what actions a rule creates.

    Args:
        target: The target under test

    Returns:
        List of mnemonic strings.

    Example:
        mnemonics = get_action_mnemonics(target)
        # ["WitBindgen", "Rustc", "WasmComponentNew", ...]
    """
    return [action.mnemonic for action in target.actions]

def assert_action_mnemonic(env, action, expected):
    """Assert that an action has the expected mnemonic.

    Args:
        env: The analysis test environment
        action: The action to check
        expected: Expected mnemonic string

    Example:
        assert_action_mnemonic(env, action, "WitBindgenRust")
    """
    asserts.equals(
        env,
        expected,
        action.mnemonic,
        "Action mnemonic mismatch",
    )

def assert_argv_contains(env, action, flag):
    """Assert that an action's argv contains a specific flag or argument.

    Args:
        env: The analysis test environment
        action: The action to check
        flag: The flag/argument to look for (e.g., "--target=wasm32-wasip2")

    Example:
        assert_argv_contains(env, rustc_action, "--target=wasm32-wasip2")
        assert_argv_contains(env, rustc_action, "-C opt-level=3")
    """
    asserts.true(
        env,
        flag in action.argv,
        "Expected '{}' in action arguments. Got: {}".format(flag, action.argv),
    )

def assert_argv_contains_prefix(env, action, prefix):
    """Assert that an action's argv contains an argument starting with prefix.

    Useful for checking flags with variable values like paths.

    Args:
        env: The analysis test environment
        action: The action to check
        prefix: The prefix to look for (e.g., "--sysroot=")

    Example:
        assert_argv_contains_prefix(env, action, "--sysroot=")
        assert_argv_contains_prefix(env, action, "-I")
    """
    found = False
    for arg in action.argv:
        if arg.startswith(prefix):
            found = True
            break
    asserts.true(
        env,
        found,
        "Expected argument starting with '{}' in action arguments".format(prefix),
    )

def assert_argv_not_contains(env, action, flag):
    """Assert that an action's argv does NOT contain a specific flag.

    Args:
        env: The analysis test environment
        action: The action to check
        flag: The flag/argument that should NOT be present

    Example:
        assert_argv_not_contains(env, action, "--debug")
    """
    asserts.false(
        env,
        flag in action.argv,
        "Unexpected '{}' in action arguments".format(flag),
    )

def assert_provider_field(env, target, provider, field, expected):
    """Assert that a provider field has the expected value.

    Args:
        env: The analysis test environment
        target: The target under test
        provider: The provider type (e.g., WasmComponentInfo)
        field: The field name to check
        expected: The expected value

    Example:
        assert_provider_field(env, target, WasmComponentInfo, "component_type", "component")
    """
    asserts.true(
        env,
        provider in target,
        "Target should provide {}".format(provider),
    )
    info = target[provider]
    asserts.true(
        env,
        hasattr(info, field),
        "{} should have '{}' field".format(provider, field),
    )
    actual = getattr(info, field)
    asserts.equals(
        env,
        expected,
        actual,
        "{}.{} value mismatch".format(provider, field),
    )

def assert_has_provider(env, target, provider):
    """Assert that a target provides a specific provider.

    Args:
        env: The analysis test environment
        target: The target under test
        provider: The provider type to check for

    Example:
        assert_has_provider(env, target, WasmComponentInfo)
    """
    asserts.true(
        env,
        provider in target,
        "Target should provide {}".format(provider),
    )

def assert_output_file_extension(env, target, extension):
    """Assert that the target's default output includes a file with given extension.

    Args:
        env: The analysis test environment
        target: The target under test
        extension: File extension to look for (e.g., ".wasm", ".wit")

    Example:
        assert_output_file_extension(env, target, ".wasm")
    """
    default_info = target[DefaultInfo]
    files = default_info.files.to_list()
    found = False
    for f in files:
        if f.basename.endswith(extension):
            found = True
            break
    asserts.true(
        env,
        found,
        "Expected output file with '{}' extension".format(extension),
    )

def assert_action_input_file(env, action, basename):
    """Assert that an action has an input file with the given basename.

    Args:
        env: The analysis test environment
        action: The action to check
        basename: The expected input file basename

    Example:
        assert_action_input_file(env, action, "main.rs")
    """
    input_basenames = [f.basename for f in action.inputs.to_list()]
    asserts.true(
        env,
        basename in input_basenames,
        "Expected input file '{}'. Got: {}".format(basename, input_basenames),
    )

def assert_action_output_file(env, action, basename):
    """Assert that an action has an output file with the given basename.

    Args:
        env: The analysis test environment
        action: The action to check
        basename: The expected output file basename

    Example:
        assert_action_output_file(env, action, "component.wasm")
    """
    output_basenames = [f.basename for f in action.outputs.to_list()]
    asserts.true(
        env,
        basename in output_basenames,
        "Expected output file '{}'. Got: {}".format(basename, output_basenames),
    )

def count_actions_by_mnemonic(target, mnemonic):
    """Count how many actions have the given mnemonic.

    Useful for verifying action graph structure.

    Args:
        target: The target under test
        mnemonic: The action mnemonic to count

    Returns:
        Number of matching actions.

    Example:
        asserts.equals(env, 1, count_actions_by_mnemonic(target, "WasmComponentNew"))
    """
    return len([a for a in target.actions if a.mnemonic == mnemonic])

def get_action_inputs_by_extension(action, extension):
    """Get all input files with a specific extension.

    Args:
        action: The action to inspect
        extension: File extension to filter by (e.g., ".rs", ".wit")

    Returns:
        List of File objects matching the extension.

    Example:
        rust_sources = get_action_inputs_by_extension(rustc_action, ".rs")
    """
    return [f for f in action.inputs.to_list() if f.basename.endswith(extension)]
