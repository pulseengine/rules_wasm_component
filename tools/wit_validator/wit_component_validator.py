#!/usr/bin/env python3
"""
WIT Component Validator

Validates that a WebAssembly component's exports match its WIT specification.
Focuses on validating the public interface (exports) while ignoring standard
library import mismatches that are common with language toolchains.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


class WitValidator:
    def __init__(self, wasm_tools_path: str = "wasm-tools"):
        self.wasm_tools = wasm_tools_path

    def extract_component_wit(self, component_path: str) -> Optional[str]:
        """Extract the WIT interface from a component using wasm-tools."""
        try:
            result = subprocess.run(
                [self.wasm_tools, "component", "wit", component_path],
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode != 0:
                print(
                    f"Error extracting component WIT: {result.stderr}", file=sys.stderr
                )
                return None

            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            print("Timeout extracting component WIT", file=sys.stderr)
            return None
        except Exception as e:
            print(f"Failed to extract component WIT: {e}", file=sys.stderr)
            return None

    def parse_wit_exports(self, wit_content: str) -> Dict[str, Set[str]]:
        """Parse WIT content and extract exported interfaces and their functions."""
        exports = {}
        current_interface = None

        lines = wit_content.split("\n")
        for line in lines:
            line = line.strip()

            # Look for export declarations in world
            if line.startswith("export ") and "@" in line:
                # Extract interface name from export declaration
                # e.g., "export example:data-structures/data-structures@1.0.0;"
                match = re.match(r"export\s+([^;]+)", line)
                if match:
                    interface_name = match.group(1).strip()
                    if interface_name not in exports:
                        exports[interface_name] = set()

            # Look for interface definitions
            elif line.startswith("interface ") and "{" not in line:
                # e.g., "interface data-structures {"
                match = re.match(r"interface\s+([^{]+)", line)
                if match:
                    current_interface = match.group(1).strip()
                    if current_interface not in exports:
                        exports[current_interface] = set()

            # Look for function definitions within interfaces
            elif current_interface and ": func(" in line and not line.startswith("//"):
                # Extract function name
                # e.g., "create-hash-table: func(name: string, config: hash-table-config) -> bool;"
                match = re.match(r"\s*([^:]+):\s*func\(", line)
                if match:
                    func_name = match.group(1).strip()
                    exports[current_interface].add(func_name)

            # End of interface
            elif line == "}" and current_interface:
                current_interface = None

        return exports

    def validate_exports(
        self, component_path: str, expected_wit_path: str, world_name: str
    ) -> bool:
        """Validate that component exports match the expected WIT specification."""
        print(f"Validating WIT exports for component: {component_path}")
        print(f"Expected WIT: {expected_wit_path}")
        print(f"World: {world_name}")

        # Extract actual component WIT
        component_wit = self.extract_component_wit(component_path)
        if not component_wit:
            return False

        # Read expected WIT file
        try:
            with open(expected_wit_path, "r") as f:
                expected_wit = f.read()
        except Exception as e:
            print(f"Failed to read expected WIT file: {e}", file=sys.stderr)
            return False

        # Parse exports from both
        component_exports = self.parse_wit_exports(component_wit)
        expected_exports = self.parse_wit_exports(expected_wit)

        print(f"Found {len(component_exports)} exported interfaces in component")
        print(f"Expected {len(expected_exports)} interfaces from WIT specification")

        # Compare exports - focus on the main interface exports
        validation_passed = True

        for interface_name, expected_functions in expected_exports.items():
            if not expected_functions:  # Skip empty interfaces
                continue

            print(f"\nValidating interface: {interface_name}")

            # Look for this interface in component exports
            component_functions = set()
            for comp_interface, comp_functions in component_exports.items():
                if interface_name in comp_interface or comp_interface in interface_name:
                    component_functions.update(comp_functions)

            if not component_functions:
                print(
                    f"  ❌ Interface '{interface_name}' not found in component exports"
                )
                validation_passed = False
                continue

            # Check for missing functions
            missing_functions = expected_functions - component_functions
            extra_functions = component_functions - expected_functions

            if missing_functions:
                print(f"  ❌ Missing functions: {sorted(missing_functions)}")
                validation_passed = False

            if extra_functions:
                print(f"  ⚠️  Extra functions: {sorted(extra_functions)}")
                # Extra functions are a warning, not an error

            if not missing_functions:
                print(f"  ✅ All {len(expected_functions)} expected functions found")

        # Summary
        if validation_passed:
            print(f"\n✅ WIT validation PASSED: Component exports match specification")
            return True
        else:
            print(
                f"\n❌ WIT validation FAILED: Component exports don't match specification"
            )
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Validate WebAssembly component WIT exports"
    )
    parser.add_argument("component", help="Path to the WebAssembly component (.wasm)")
    parser.add_argument("wit_file", help="Path to the expected WIT specification file")
    parser.add_argument("world", help="WIT world name to validate against")
    parser.add_argument(
        "--wasm-tools",
        default="wasm-tools",
        help="Path to wasm-tools binary (default: wasm-tools)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Enable verbose output"
    )

    args = parser.parse_args()

    if args.verbose:
        print(f"Component: {args.component}")
        print(f"WIT file: {args.wit_file}")
        print(f"World: {args.world}")
        print(f"wasm-tools: {args.wasm_tools}")

    # Validate inputs exist
    if not Path(args.component).exists():
        print(f"Error: Component file not found: {args.component}", file=sys.stderr)
        sys.exit(1)

    if not Path(args.wit_file).exists():
        print(f"Error: WIT file not found: {args.wit_file}", file=sys.stderr)
        sys.exit(1)

    # Create validator and run validation
    validator = WitValidator(args.wasm_tools)
    success = validator.validate_exports(args.component, args.wit_file, args.world)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
